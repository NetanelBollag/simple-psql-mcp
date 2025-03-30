-- PostgreSQL seed file to generate 1000 additional users and addresses
-- This builds on the existing schema with users and addresses tables

-- Function to generate random strings for names, streets, etc.
CREATE OR REPLACE FUNCTION random_string(length INTEGER) RETURNS TEXT AS
$$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  result TEXT := '';
  i INTEGER := 0;
BEGIN
  FOR i IN 1..length LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to generate random phone numbers
CREATE OR REPLACE FUNCTION random_phone() RETURNS TEXT AS
$$
BEGIN
  RETURN 
    LPAD(floor(random() * 900 + 100)::TEXT, 3, '0') || '-' || 
    LPAD(floor(random() * 900 + 100)::TEXT, 3, '0') || '-' || 
    LPAD(floor(random() * 9000 + 1000)::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Array of common street types
CREATE TEMP TABLE street_types AS
SELECT unnest(ARRAY['Street', 'Avenue', 'Boulevard', 'Road', 'Lane', 'Drive', 'Way', 'Court', 'Plaza', 'Terrace']) AS name;

-- Array of common first names
CREATE TEMP TABLE first_names AS
SELECT unnest(ARRAY[
  'James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Linda', 'William', 'Elizabeth',
  'David', 'Susan', 'Richard', 'Jessica', 'Joseph', 'Sarah', 'Thomas', 'Karen', 'Charles', 'Nancy',
  'Christopher', 'Lisa', 'Daniel', 'Margaret', 'Matthew', 'Betty', 'Anthony', 'Sandra', 'Mark', 'Ashley',
  'Donald', 'Kimberly', 'Steven', 'Emily', 'Paul', 'Donna', 'Andrew', 'Michelle', 'Joshua', 'Dorothy',
  'Kenneth', 'Carol', 'Kevin', 'Amanda', 'Brian', 'Melissa', 'George', 'Deborah', 'Edward', 'Stephanie'
]) AS name;

-- Array of common last names
CREATE TEMP TABLE last_names AS
SELECT unnest(ARRAY[
  'Smith', 'Johnson', 'Williams', 'Jones', 'Brown', 'Davis', 'Miller', 'Wilson', 'Moore', 'Taylor',
  'Anderson', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Thompson', 'Garcia', 'Martinez', 'Robinson',
  'Clark', 'Rodriguez', 'Lewis', 'Lee', 'Walker', 'Hall', 'Allen', 'Young', 'Hernandez', 'King',
  'Wright', 'Lopez', 'Hill', 'Scott', 'Green', 'Adams', 'Baker', 'Gonzalez', 'Nelson', 'Carter',
  'Mitchell', 'Perez', 'Roberts', 'Turner', 'Phillips', 'Campbell', 'Parker', 'Evans', 'Edwards', 'Collins'
]) AS name;

-- Array of cities
CREATE TEMP TABLE cities AS
SELECT unnest(ARRAY[
  'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 
  'Dallas', 'San Jose', 'Austin', 'Jacksonville', 'Fort Worth', 'Columbus', 'Indianapolis', 'Charlotte', 
  'San Francisco', 'Seattle', 'Denver', 'Washington', 'Boston', 'El Paso', 'Nashville', 'Detroit', 'Portland'
]) AS city,
unnest(ARRAY[
  'NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'TX', 'CA', 
  'TX', 'CA', 'TX', 'FL', 'TX', 'OH', 'IN', 'NC', 
  'CA', 'WA', 'CO', 'DC', 'MA', 'TX', 'TN', 'MI', 'OR'
]) AS state;

-- Begin transaction
BEGIN;

-- Get the current max IDs to know where to start
DO $$
DECLARE
  max_address_id INTEGER;
  max_user_id INTEGER;
  address_id INTEGER;
  first_name TEXT;
  last_name TEXT;
  street_num INTEGER;
  street_name TEXT;
  street_type TEXT;
  city_rec RECORD;
  postal_code TEXT;
  email TEXT;
  i INTEGER;
BEGIN
  -- Get max IDs
  SELECT COALESCE(MAX(address_id), 0) INTO max_address_id FROM addresses;
  SELECT COALESCE(MAX(user_id), 0) INTO max_user_id FROM users;
  
  -- Generate 1000 new records
  FOR i IN 1..1000 LOOP
    -- Generate address data
    address_id := max_address_id + i;
    street_num := floor(random() * 9900 + 100)::INTEGER;
    street_name := (SELECT name FROM first_names ORDER BY random() LIMIT 1);
    street_type := (SELECT name FROM street_types ORDER BY random() LIMIT 1);
    SELECT * INTO city_rec FROM cities ORDER BY random() LIMIT 1;
    postal_code := LPAD(floor(random() * 90000 + 10000)::TEXT, 5, '0');
    
    -- Insert address
    INSERT INTO addresses (street_address, city, state, postal_code, country)
    VALUES (
      street_num || ' ' || street_name || ' ' || street_type,
      city_rec.city,
      city_rec.state,
      postal_code,
      'USA'
    );
    
    -- Generate user data
    first_name := (SELECT name FROM first_names ORDER BY random() LIMIT 1);
    last_name := (SELECT name FROM last_names ORDER BY random() LIMIT 1);
    email := lower(first_name) || '.' || lower(last_name) || i || '@example.com';
    
    -- Insert user with reference to the new address
    INSERT INTO users (first_name, last_name, email, phone, address_id)
    VALUES (
      first_name,
      last_name,
      email,
      random_phone(),
      address_id
    );
  END LOOP;
END $$;

-- Verify the data was inserted
SELECT COUNT(*) AS total_addresses FROM addresses;
SELECT COUNT(*) AS total_users FROM users;

-- Clean up temporary functions and tables
DROP FUNCTION IF EXISTS random_string;
DROP FUNCTION IF EXISTS random_phone;
DROP TABLE IF EXISTS street_types;
DROP TABLE IF EXISTS first_names;
DROP TABLE IF EXISTS last_names;
DROP TABLE IF EXISTS cities;

COMMIT;


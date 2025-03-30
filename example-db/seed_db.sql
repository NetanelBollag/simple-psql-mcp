-- Create addresses table
CREATE TABLE addresses (
  address_id SERIAL PRIMARY KEY,
  street_address VARCHAR(100) NOT NULL,
  city VARCHAR(50) NOT NULL,
  state VARCHAR(50) NOT NULL,
  postal_code VARCHAR(20) NOT NULL,
  country VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create users table
CREATE TABLE users (
  user_id SERIAL PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  phone VARCHAR(20),
  address_id INTEGER REFERENCES addresses(address_id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert 10 addresses
INSERT INTO addresses (street_address, city, state, postal_code, country) VALUES
  ('123 Oak Street', 'New York', 'NY', '10001', 'USA'),
  ('456 Pine Avenue', 'Los Angeles', 'CA', '90001', 'USA'),
  ('789 Maple Road', 'Chicago', 'IL', '60007', 'USA'),
  ('321 Cedar Lane', 'Houston', 'TX', '77001', 'USA'),
  ('654 Birch Boulevard', 'Philadelphia', 'PA', '19019', 'USA'),
  ('987 Spruce Court', 'Phoenix', 'AZ', '85001', 'USA'),
  ('135 Willow Way', 'San Antonio', 'TX', '78201', 'USA'),
  ('246 Redwood Drive', 'San Diego', 'CA', '92101', 'USA'),
  ('579 Elm Street', 'Dallas', 'TX', '75201', 'USA'),
  ('864 Aspen Circle', 'San Jose', 'CA', '95101', 'USA');

-- Insert 10 users linked to addresses
INSERT INTO users (first_name, last_name, email, phone, address_id) VALUES
  ('John', 'Doe', 'john.doe@example.com', '212-555-1234', 1),
  ('Jane', 'Smith', 'jane.smith@example.com', '310-555-2345', 2),
  ('Michael', 'Johnson', 'michael.johnson@example.com', '312-555-3456', 3),
  ('Emily', 'Williams', 'emily.williams@example.com', '713-555-4567', 4),
  ('Robert', 'Brown', 'robert.brown@example.com', '267-555-5678', 5),
  ('Sarah', 'Miller', 'sarah.miller@example.com', '602-555-6789', 6),
  ('David', 'Wilson', 'david.wilson@example.com', '210-555-7890', 7),
  ('Jessica', 'Taylor', 'jessica.taylor@example.com', '619-555-8901', 8),
  ('Christopher', 'Anderson', 'christopher.anderson@example.com', '214-555-9012', 9),
  ('Amanda', 'Martinez', 'amanda.martinez@example.com', '408-555-0123', 10);

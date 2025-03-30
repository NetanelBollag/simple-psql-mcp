#!/bin/bash

# Script to set up PostgreSQL container and initialize database with users and addresses

# Define container name and credentials
CONTAINER_NAME="postgres_local"
DB_NAME="user_database"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_PORT="5432"

# Stop and remove container if it already exists
echo "Stopping and removing existing container if it exists..."
docker stop $CONTAINER_NAME 2>/dev/null
docker rm $CONTAINER_NAME 2>/dev/null

# Run PostgreSQL container
echo "Starting PostgreSQL container..."
docker run --name $CONTAINER_NAME \
  -e POSTGRES_PASSWORD=$DB_PASSWORD \
  -e POSTGRES_DB=$DB_NAME \
  -p $DB_PORT:5432 \
  -d postgres:14

# Wait for PostgreSQL to initialize
echo "Waiting for PostgreSQL to initialize..."
sleep 10

# Create SQL script for database setup
cat > init_db.sql << EOF
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
EOF

# Execute SQL script
echo "Initializing database with sample data..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME < init_db.sql

# Verify data was inserted
echo "Verifying data insertion..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM users;"
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM addresses;"

echo "Database setup complete!"
echo "PostgreSQL is running on localhost:$DB_PORT"
echo "Database: $DB_NAME"
echo "Username: $DB_USER"
echo "Password: $DB_PASSWORD"

# Display connection command example
echo ""
echo "To connect directly to the PostgreSQL client, run:"
echo "docker exec -it $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME"

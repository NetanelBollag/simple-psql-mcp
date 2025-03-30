#!/bin/bash

# Find the uv executable path
UV_PATH=$(which uv)
if [ -z "$UV_PATH" ]; then
  echo "Error: 'uv' executable not found in PATH"
  exit 1
fi

# Get current working directory
CURRENT_DIR=$(pwd)

# Prompt for DSN and schema
read -p "Enter PostgreSQL DSN (e.g., postgresql://postgres:postgres@localhost:5432/user_database): " DSN
read -p "Enter schema name (press Enter for public): " DB_SCHEMA
DB_SCHEMA=${DB_SCHEMA:-public}

# Create the JSON configuration
cat > mcp_config.json << EOF
{
  "mcpServers": {
    "postgres": {
      "command": "${UV_PATH}",
      "args": [
        "--directory",
        "${CURRENT_DIR}",
        "run",
        "postgres"
      ],
      "env": {
        "DSN": "${DSN}",
        "SCHEMA": "${DB_SCHEMA}"
      }
    }
  }
}
EOF

cat mcp_config.json
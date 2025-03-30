# Simple PostgreSQL MCP Server

This is a template project for those looking to build their own MCP servers. I designed it to be dead simple to understand and adapt - the code is straightforward with MCP docs attached so you can quickly get up to speed.

## What is MCP?

Model Context Protocol (MCP) is a standard way for LLMs to interact with external tools and data. In a nutshell:

- **Tools** allow the LLM to execute commands (like running a database query)
- **Resources** are data you can attach to conversations (like attaching a file to a prompt)
- **Prompts** are templates that generate consistent LLM instructions

## Features

This PostgreSQL MCP server implements:

1. **Tools**
   - `execute_query` - Run SQL queries against your database
   - `test_connection` - Verify the database connection is working

2. **Resources**
   - The list of tables in database schema

3. **Prompts**
   - Query generation templates
   - Analytical query builders
   - Based on the templates in this repo

## Documentation

- MCP docs included for easy LLM development
- Based on the approach at: https://modelcontextprotocol.io/tutorials/building-mcp-with-llms
- Python SDK is only accurate to the day of creation, so please RTFM and copy paste it on your own

## Prerequisites

- Python 3.8+
- pip
- npx
- PostgreSQL database you feel comfortable to connect to LLM

## Installation and Running

1. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Run the server with the MCP Inspector:
   ```
   npx @modelcontextprotocol/inspector uv --directory . run postgres -e DATABASE_URL="postgresql://$DB_USER:$DB_PASSWORD@host:5432/my-db"
   ```

More on the inspector: https://modelcontextprotocol.io/docs/tools/inspector

## Configuration for AI Assistants

Add this MCP server to your AI assistant's configuration:

You may need to put the full path to the uv executable in the command field. You can get this by running `which uv` on MacOS/Linux or `where uv` on Windows.

```json
{
  "mcpServers": {
    "postgres": {
      "command": "/Users/username/.local/bin/uv",
      "args": [
        "--directory",
        "/path/to/simple-psql-mcp",
        "run",
        "postgres"
      ],
      "env": {
        "DSN": "postgresql://username:password@localhost:5432/my-db",
        "SCHEMA": "public"
      }
    }
  }
}
```

## First Flow

Here's a step-by-step guide to get started with this PostgreSQL MCP server:

1. **Set up your environment**
   ```
   # Create and activate virtual environment
   python -m venv .venv
   source .venv/bin/activate  # On macOS/Linux
   # Or: .venv\Scripts\activate  # On Windows
   
   # Install dependencies
   pip install -r requirements.txt
   ```

2. **Configure your database connection**
   - Edit the DSN in your configuration to point to your PostgreSQL database
   - Make sure your database is running and accessible

3. **Start the MCP server**
   ```
   npx @modelcontextprotocol/inspector uv --directory . run postgres -e DSN="postgresql://username:password@localhost:5432/my-db" -e SCHEMA="public"
   ```

4. **Test the connection**
   - Use the `test_connection` tool to verify everything is working
   - Try a simple query like: `SELECT version();`

5. **Run your first query**
   - Use the `execute_query` tool with a SQL query
   - Example: `SELECT * FROM your_table LIMIT 5;`

6. **Explore your schema**
   - The server automatically provides schema information as a resource
   - Ask your AI assistant about available tables and their structures

## Security

This is an experimental project meant to empower developers to create their own MCP server. I did minimum to make sure it won't die immediately when you try it, but be careful - it's very easy to run SQL injections with this tool. The server will check if the query starts with SELECT, but beyond that nothing is guaranteed. TL;DR - don't run in production unless you're the founder and there are no paying clients.

## License

MIT
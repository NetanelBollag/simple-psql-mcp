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
   - The server checks which tables exist, list them, and when choosing one the schema is attached to the prompt

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

1. Create a virtual environment and install dependencies:
   ```
   uv venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   uv pip install -r requirements.txt
   ```

2. Run the server with the MCP Inspector:
   ```
   npx @modelcontextprotocol/inspector uv --directory . run postgres -e DSN=postgresql://postgres:postgres@localhost:5432/user_database -e SCHEMA=public
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

## Security

This is an experimental project meant to empower developers to create their own MCP server. I did minimum to make sure it won't die immediately when you try it, but be careful - it's very easy to run SQL injections with this tool. The server will check if the query starts with SELECT, but beyond that nothing is guaranteed. TL;DR - don't run in production unless you're the founder and there are no paying clients.

## License

MIT
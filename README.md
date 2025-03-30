# Simple PostgreSQL MCP Server

This is a template project for those looking to build their own MCP servers. I designed it to be dead simple to understand and adapt - the code is straightforward with MCP docs attached so you can quickly get up to speed.

## Features

- Database schema information accessible as resources
- SQL query execution as tools
- SQL query templates as prompts
- MCP docs to easily add documentation for the LLM when developing your project, based on instructions at: https://modelcontextprotocol.io/tutorials/building-mcp-with-llms (Python SDK is only accurate to the day of creation, so please RTFM and copy paste it on your own)

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

Add this MCP server to your AI assistant's configuration

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

This is an experimental project meant to empower developers to create their own MCP server. I did minimum to make sure it won't die immediately when you try it, but be careful - it's very easy to run SQL injections with this tool. TL;DR - don't run in production unless you're the founder and there are no paying clients.


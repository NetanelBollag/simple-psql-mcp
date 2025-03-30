
# SQL Database MCP Server - Requirements

This document outlines the development of a simple MCP server that provides database interface capabilities through the Model Context Protocol. The server will allow LLMs to query database schema information as resources and execute read-only SQL queries as tools.

## Overview

The SQL Database MCP Server will connect to a PostgreSQL database and expose:
1. Database schema information as resources
2. SQL query execution as tools
3. Common SQL query templates as prompts

The implementation will follow a phased approach to incrementally build and test functionality.

## Phase 1: Project Structure and Basic API Implementation

In this phase, we'll establish the project structure and implement the basic API to make features visible in the MCP inspector tool, returning hardcoded responses.

### Requirements:
- Set up the project directory structure
- Implement a basic FastMCP server
- Define the tools, resources, and prompts with hardcoded responses
- Ensure the server runs and can be inspected with the MCP inspector tool

### Example:

```python
from mcp.server.fastmcp import FastMCP

# Create an MCP server
mcp = FastMCP("SQL Database Server")

# Add a tool with hardcoded response
@mcp.tool()
def execute_query(query: str) -> str:
    """Execute a read-only SQL query against the database"""
    return "Sample query result (hardcoded)"

# Add a resource with hardcoded response
@mcp.resource("db://tables")
def list_tables() -> str:
    """List all tables in the database"""
    return "Table1\nTable2\nTable3"

# Add a prompt template
@mcp.prompt()
def select_query(table_name: str) -> str:
    """Generate a SELECT query for a table"""
    return f"SELECT * FROM {table_name} LIMIT 10;"
```

## Phase 2: Database Connection Setup

In this phase, we'll implement database connection functionality using environment variables.

### Requirements:
- Add PostgreSQL dependencies
- Implement database connection configuration using environment variables
- Create connection pool management
- Add error handling for connection issues
- Implement a test connection feature

### Example:

```python
import os
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import AsyncIterator

import asyncpg
from mcp.server.fastmcp import Context, FastMCP

# Create the server
mcp = FastMCP("SQL Database Server", dependencies=["asyncpg"])

@dataclass
class DbContext:
    pool: asyncpg.Pool

@asynccontextmanager
async def db_lifespan(server: FastMCP) -> AsyncIterator[DbContext]:
    """Manage database connection lifecycle"""
    # Initialize DB connection
    dsn = os.environ.get("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/postgres")
    pool = await asyncpg.create_pool(dsn)
    try:
        yield DbContext(pool=pool)
    finally:
        # Clean up
        await pool.close()

# Pass lifespan to server
mcp = FastMCP("SQL Database Server", dependencies=["asyncpg"], lifespan=db_lifespan)

@mcp.tool()
async def test_connection(ctx: Context) -> str:
    """Test database connection"""
    pool = ctx.request_context.lifespan_context.pool
    async with pool.acquire() as conn:
        result = await conn.fetchval("SELECT version();")
    return f"Connection successful. PostgreSQL version: {result}"
```

## Phase 3: Implement SQL Query Tool

In this phase, we'll implement the tool for forwarding SQL queries to the database.

### Requirements:
- Implement the execute_query tool that sends SQL to the database
- Add query validation to ensure only read-only queries are executed
- Include error handling for SQL syntax errors
- Format query results as human-readable text
- Add query timeout and result size limits for safety

### Example:

```python
@mcp.tool()
async def execute_query(query: str, ctx: Context) -> str:
    """
    Execute a read-only SQL query against the database.
    Only SELECT statements are allowed.
    """
    # Validate query - simple check for read-only
    query = query.strip()
    if not query.lower().startswith("select"):
        return "Error: Only SELECT queries are allowed for security reasons."
    
    # Execute query
    pool = ctx.request_context.lifespan_context.pool
    try:
        async with pool.acquire() as conn:
            result = await conn.fetch(query, timeout=5.0)
            
            # Format results
            if not result:
                return "Query executed successfully. No rows returned."
                
            # Create table header
            columns = [k for k in result[0].keys()]
            header = " | ".join(columns)
            separator = "-" * len(header)
            
            # Format rows
            rows = [" | ".join(str(val) for val in row.values()) for row in result[:100]]
            
            # Combine and return
            return f"{header}\n{separator}\n" + "\n".join(rows)
    except asyncpg.exceptions.PostgresError as e:
        return f"SQL Error: {str(e)}"
    except Exception as e:
        return f"Error: {str(e)}"
```

## Phase 4: Implement Table Schema Resources

In this phase, we'll implement resources that provide database schema information.

### Requirements:
- Implement a resource to list all tables
- Implement a resource to show schema for a specific table
- Include column information (name, type, constraints)
- Format schema information in a clear, structured way

### Example:

```python
@mcp.resource("db://tables")
async def list_tables(ctx: Context) -> str:
    """List all tables in the database"""
    pool = ctx.request_context.lifespan_context.pool
    async with pool.acquire() as conn:
        tables = await conn.fetch("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name
        """)
    return "\n".join(table["table_name"] for table in tables)

@mcp.resource("db://tables/{table_name}")
async def get_table_schema(table_name: str, ctx: Context) -> str:
    """Get schema for a specific table"""
    pool = ctx.request_context.lifespan_context.pool
    async with pool.acquire() as conn:
        columns = await conn.fetch("""
            SELECT 
                column_name, 
                data_type, 
                is_nullable, 
                column_default
            FROM 
                information_schema.columns 
            WHERE 
                table_schema = 'public' AND 
                table_name = $1
            ORDER BY 
                ordinal_position
        """, table_name)
        
        if not columns:
            return f"Table '{table_name}' not found."
        
        result = [f"Table: {table_name}", "Columns:"]
        for col in columns:
            nullable = "NULL" if col["is_nullable"] == "YES" else "NOT NULL"
            default = f" DEFAULT {col['column_default']}" if col["column_default"] else ""
            result.append(f"  - {col['column_name']} ({col['data_type']}) {nullable}{default}")
            
        return "\n".join(result)
```

## Phase 5: Implement SQL Templates as Prompts

In this phase, we'll implement SQL template prompts to help generate common queries.

### Requirements:
- Implement a SELECT query template prompt
- Implement an analytical query template prompt
- Include best practices instructions in the prompt
- Make templates aware of actual database schema

### Example:

```python
@mcp.prompt()
async def generate_select_query(table_name: str, ctx: Context) -> list[types.PromptMessage]:
    """Generate a SELECT query with best practices for a table"""
    # Get column information to make the prompt context-aware
    pool = ctx.request_context.lifespan_context.pool
    async with pool.acquire() as conn:
        columns = await conn.fetch("""
            SELECT column_name, data_type
            FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = $1
            ORDER BY ordinal_position
        """, table_name)
    
    if not columns:
        return [types.UserMessage(f"Table '{table_name}' not found.")]
    
    columns_text = "\n".join([f"- {col['column_name']} ({col['data_type']})" for col in columns])
    
    return [
        types.UserMessage(
            f"""Please help me write a well-structured, efficient SELECT query for the '{table_name}' table.

Table Schema:
{columns_text}

PostgreSQL SQL Best Practices:
- Use explicit column names instead of * when possible
- Include LIMIT clauses to restrict result sets
- Consider adding WHERE clauses to filter results
- Use appropriate indexing considerations
- Format SQL with proper indentation and line breaks

Create a basic SELECT query following these best practices:"""
        )
    ]

@mcp.prompt()
async def generate_analytical_query(table_name: str, ctx: Context) -> list[types.PromptMessage]:
    """Generate analytical queries for a table"""
    # Get column information
    pool = ctx.request_context.lifespan_context.pool
    async with pool.acquire() as conn:
        columns = await conn.fetch("""
            SELECT column_name, data_type
            FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = $1
            ORDER BY ordinal_position
        """, table_name)
    
    if not columns:
        return [types.UserMessage(f"Table '{table_name}' not found.")]
    
    columns_text = "\n".join([f"- {col['column_name']} ({col['data_type']})" for col in columns])
    
    return [
        types.UserMessage(
            f"""Please help me create analytical queries for the '{table_name}' table.

Table Schema:
{columns_text}

PostgreSQL SQL Best Practices:
- Use aggregation functions (COUNT, SUM, AVG, MIN, MAX) appropriately
- Group data using GROUP BY for meaningful aggregations
- Filter groups with HAVING clauses when needed
- Consider using window functions for advanced analytics
- Format SQL with proper indentation and line breaks

Create a set of analytical queries for this table:"""
        )
    ]
```

## Summary of Deliverables

1. **Phase 1**: Basic project structure with hardcoded responses
2. **Phase 2**: Database connection functionality
3. **Phase 3**: SQL query execution tool
4. **Phase 4**: Table schema resources
5. **Phase 5**: SQL templates as prompts

## Technical Requirements

- Python 3.10+
- PostgreSQL database
- MCP Python SDK 1.2.0+
- asyncpg for PostgreSQL connection
- Environment variables for database configuration

## Development Tools

- MCP Inspector for testing
- Claude Desktop for end-user testing

## Security Considerations

- Read-only query validation
- Query timeout limits
- Result size restrictions
- Environment variable based configuration
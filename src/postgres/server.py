"""
FastMCP SQL Database Server
"""

import os
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Optional, AsyncIterator

import asyncpg
from mcp.server.fastmcp import FastMCP, Context
from pydantic import Field

# Constants
DEFAULT_QUERY_LIMIT = 100
DEFAULT_SCHEMA = "public"

# Define our own PromptMessage class if the MCP one isn't available
@dataclass
class PromptMessage:
    content: str
    role: Optional[str] = "user"

# Database context class
@dataclass
class DbContext:
    pool: asyncpg.Pool
    schema: str

# Database connection lifecycle manager
@asynccontextmanager
async def db_lifespan(server: FastMCP) -> AsyncIterator[DbContext]:
    """Manage database connection lifecycle"""
    # Initialize DB connection from environment variables
    dsn = os.environ.get("DSN", "postgresql://postgres:postgres@localhost:5432/postgres")
    schema = os.environ.get("SCHEMA", DEFAULT_SCHEMA)
    pool = await asyncpg.create_pool(dsn)
    try:
        yield DbContext(pool=pool, schema=schema)
    finally:
        # Clean up
        await pool.close()

# Create server with database lifecycle management
mcp = FastMCP(
    "SQL Database Server",
    dependencies=["asyncpg", "pydantic"],
    lifespan=db_lifespan
)

@mcp.tool()
async def test_connection(ctx: Context) -> str:
    """Test database connection"""
    try:
        pool = ctx.request_context.lifespan_context.pool
        async with pool.acquire() as conn:
            version = await conn.fetchval("SELECT version();")
        return f"Connection successful. PostgreSQL version: {version}"
    except Exception as e:
        return f"Connection failed: {str(e)}"

@mcp.tool()
async def execute_query(
    query: str = Field(description="SQL query to execute (SELECT only)"),
    limit: Optional[int] = Field(default=DEFAULT_QUERY_LIMIT, description="Maximum number of rows to return"),
    ctx: Context = None
) -> str:
    """Execute a read-only SQL query against the database"""
    # Validate query - simple check for read-only
    query = query.strip()
    if not query.lower().startswith("select"):
        return "Error: Only SELECT queries are allowed for security reasons."
    
    try:
        pool = ctx.request_context.lifespan_context.pool
        async with pool.acquire() as conn:
            result = await conn.fetch(query)
            
            if not result:
                return "Query executed successfully. No rows returned."
                
            # Format results
            columns = [k for k in result[0].keys()]
            header = " | ".join(columns)
            separator = "-" * len(header)
            
            # Format rows with limit
            rows = [" | ".join(str(val) for val in row.values()) 
                   for row in result[:limit if limit else DEFAULT_QUERY_LIMIT]]
            
            return f"{header}\n{separator}\n" + "\n".join(rows)
    except asyncpg.exceptions.PostgresError as e:
        return f"SQL Error: {str(e)}"
    except Exception as e:
        return f"Error: {str(e)}"

# Database helper functions
async def get_all_tables(pool, schema):
    """Get all tables from the database"""
    async with pool.acquire() as conn:
        result = await conn.fetch("""
            SELECT c.relname AS table_name
            FROM pg_class AS c
            JOIN pg_namespace AS n ON n.oid = c.relnamespace
            WHERE NOT EXISTS (
                SELECT 1
                FROM pg_inherits AS i
                WHERE i.inhrelid = c.oid
            )
            AND c.relkind IN ('r', 'p')
            AND n.nspname = $1
            AND c.relname NOT LIKE 'pg_%'
            ORDER BY c.relname;
        """, schema)
        
        return result

async def get_table_schema_info(pool, schema, table_name):
    """Get schema information for a specific table"""
    async with pool.acquire() as conn:
        columns = await conn.fetch("""
            SELECT
                column_name,
                data_type,
                is_nullable,
                column_default,
                character_maximum_length
            FROM information_schema.columns
            WHERE table_schema = $1
            AND table_name = $2
            ORDER BY ordinal_position;
        """, schema, table_name)
        
        return columns

def format_table_schema(table_name, columns):
    """Format table schema into readable text"""
    if not columns:
        return f"Table '{table_name}' not found."
        
    result = [f"Table: {table_name}", "Columns:"]
    for col in columns:
        nullable = "NULL" if col['is_nullable'] == 'YES' else "NOT NULL"
        length = f"({col['character_maximum_length']})" if col['character_maximum_length'] else ""
        default = f" DEFAULT {col['column_default']}" if col['column_default'] else ""
        result.append(f"- {col['column_name']} ({col['data_type']}{length}) {nullable}{default}")
    
    return "\n".join(result)

@mcp.resource("db://tables")
async def list_tables() -> str:
    """List all tables in the database"""
    try:
        async with db_lifespan(mcp) as db_ctx:
            result = await get_all_tables(db_ctx.pool, db_ctx.schema)
            
            if not result:
                return f"No tables found in the {db_ctx.schema} schema."

            return "\n".join(row['table_name'] for row in result)
    except asyncpg.exceptions.PostgresError as e:
        return f"SQL Error: {str(e)}"
    except Exception as e:
        return f"Error: {str(e)}"

@mcp.resource("db://tables/{table_name}")
async def get_table_schema(table_name: str) -> str:
    """Get schema information for a specific table"""
    try:
        schema = os.environ.get("SCHEMA", DEFAULT_SCHEMA)

        async with db_lifespan(mcp) as db_ctx:
            columns = await get_table_schema_info(db_ctx.pool, schema, table_name)
            
            if not columns:
                return f"Table '{table_name}' not found in {schema} schema."
            
            return format_table_schema(table_name, columns)
    except asyncpg.exceptions.PostgresError as e:
        return f"SQL Error: {str(e)}"
    except Exception as e:
        return f"Error: {str(e)}"

@mcp.resource("db://schema")
async def get_all_schemas() -> str:
    """Get schema information for all tables in the database"""
    try:
        schema = os.environ.get("SCHEMA", DEFAULT_SCHEMA)
        
        async with db_lifespan(mcp) as db_ctx:
            tables = await get_all_tables(db_ctx.pool, db_ctx.schema)
            
            if not tables:
                return f"No tables found in the {db_ctx.schema} schema."
            
            all_schemas = []
            for table in tables:
                table_name = table['table_name']
                columns = await get_table_schema_info(db_ctx.pool, schema, table_name)
                table_schema = format_table_schema(table_name, columns)
                all_schemas.append(table_schema)
                all_schemas.append("") # Add empty line between tables
            
            return "\n".join(all_schemas)
    except asyncpg.exceptions.PostgresError as e:
        return f"SQL Error: {str(e)}"
    except Exception as e:
        return f"Error: {str(e)}"

@mcp.prompt()
async def generate_select_query(table_name: str) -> list[PromptMessage]:
    """Generate a SELECT query with best practices for a table"""
    try:
        async with db_lifespan(mcp) as db_ctx:
            pool = db_ctx.pool
            async with pool.acquire() as conn:
                columns = await conn.fetch("""
                    SELECT column_name, data_type
                    FROM information_schema.columns 
                    WHERE table_schema = $1 AND table_name = $2
                    ORDER BY ordinal_position
                """, db_ctx.schema, table_name)
            
            if not columns:
                return [PromptMessage(f"Table '{table_name}' not found in schema '{db_ctx.schema}'.")]
            
            columns_text = "\n".join([f"- {col['column_name']} ({col['data_type']})" for col in columns])
            
            return [
                PromptMessage(
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
    except Exception as e:
        return [PromptMessage(f"Error generating select query: {str(e)}")]

@mcp.prompt()
async def generate_analytical_query(table_name: str) -> list[PromptMessage]:
    """Generate analytical queries for a table"""
    try:
        async with db_lifespan(mcp) as db_ctx:
            pool = db_ctx.pool
            async with pool.acquire() as conn:
                columns = await conn.fetch("""
                    SELECT column_name, data_type
                    FROM information_schema.columns 
                    WHERE table_schema = $1 AND table_name = $2
                    ORDER BY ordinal_position
                """, db_ctx.schema, table_name)
            
            if not columns:
                return [PromptMessage(f"Table '{table_name}' not found in schema '{db_ctx.schema}'.")]
            
            columns_text = "\n".join([f"- {col['column_name']} ({col['data_type']})" for col in columns])
            
            return [
                PromptMessage(
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
    except Exception as e:
        return [PromptMessage(f"Error generating analytical query: {str(e)}")]

def main():
    mcp.run()

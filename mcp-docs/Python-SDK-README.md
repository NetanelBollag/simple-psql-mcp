# MCP Python SDK

<div align="center">

<strong>Python implementation of the Model Context Protocol (MCP)</strong>

[![PyPI][pypi-badge]][pypi-url]
[![MIT licensed][mit-badge]][mit-url]
[![Python Version][python-badge]][python-url]
[![Documentation][docs-badge]][docs-url]
[![Specification][spec-badge]][spec-url]
[![GitHub Discussions][discussions-badge]][discussions-url]

</div>

<!-- omit in toc -->
## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What is MCP?](#what-is-mcp)
- [Core Concepts](#core-concepts)
    - [Server](#server)
    - [Resources](#resources)
    - [Tools](#tools)
    - [Prompts](#prompts)
    - [Images](#images)
    - [Context](#context)
- [Running Your Server](#running-your-server)
    - [Development Mode](#development-mode)
    - [Claude Desktop Integration](#claude-desktop-integration)
    - [Direct Execution](#direct-execution)
- [Examples](#examples)
    - [Echo Server](#echo-server)
    - [SQLite Explorer](#sqlite-explorer)
- [Advanced Usage](#advanced-usage)
    - [Low-Level Server](#low-level-server)
    - [Writing MCP Clients](#writing-mcp-clients)
    - [MCP Primitives](#mcp-primitives)
    - [Server Capabilities](#server-capabilities)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

[pypi-badge]: https://img.shields.io/pypi/v/mcp.svg
[pypi-url]: https://pypi.org/project/mcp/
[mit-badge]: https://img.shields.io/pypi/l/mcp.svg
[mit-url]: https://github.com/modelcontextprotocol/python-sdk/blob/main/LICENSE
[python-badge]: https://img.shields.io/pypi/pyversions/mcp.svg
[python-url]: https://www.python.org/downloads/
[docs-badge]: https://img.shields.io/badge/docs-modelcontextprotocol.io-blue.svg
[docs-url]: https://modelcontextprotocol.io
[spec-badge]: https://img.shields.io/badge/spec-spec.modelcontextprotocol.io-blue.svg
[spec-url]: https://spec.modelcontextprotocol.io
[discussions-badge]: https://img.shields.io/github/discussions/modelcontextprotocol/python-sdk
[discussions-url]: https://github.com/modelcontextprotocol/python-sdk/discussions

## Overview

The Model Context Protocol allows applications to provide context for LLMs in a standardized way, separating the concerns of providing context from the actual LLM interaction. This Python SDK implements the full MCP specification, making it easy to:

- Build MCP clients that can connect to any MCP server
- Create MCP servers that expose resources, prompts and tools
- Use standard transports like stdio and SSE
- Handle all MCP protocol messages and lifecycle events

## Installation

### Adding MCP to your python project

We recommend using [uv](https://docs.astral.sh/uv/) to manage your Python projects. In a uv managed python project, add mcp to dependencies by:

```bash
uv add "mcp[cli]"
```

Alternatively, for projects using pip for dependencies:
```bash
pip install mcp
```

### Running the standalone MCP development tools

To run the mcp command with uv:

```bash
uv run mcp
```

## Quickstart

Let's create a simple MCP server that exposes a calculator tool and some data:

```python
# server.py
from mcp.server.fastmcp import FastMCP

# Create an MCP server
mcp = FastMCP("Demo")


# Add an addition tool
@mcp.tool()
def add(a: int, b: int) -> int:
    """Add two numbers"""
    return a + b


# Add a dynamic greeting resource
@mcp.resource("greeting://{name}")
def get_greeting(name: str) -> str:
    """Get a personalized greeting"""
    return f"Hello, {name}!"
```

You can install this server in [Claude Desktop](https://claude.ai/download) and interact with it right away by running:
```bash
mcp install server.py
```

Alternatively, you can test it with the MCP Inspector:
```bash
mcp dev server.py
```

## What is MCP?

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io) lets you build servers that expose data and functionality to LLM applications in a secure, standardized way. Think of it like a web API, but specifically designed for LLM interactions. MCP servers can:

- Expose data through **Resources** (think of these sort of like GET endpoints; they are used to load information into the LLM's context)
- Provide functionality through **Tools** (sort of like POST endpoints; they are used to execute code or otherwise produce a side effect)
- Define interaction patterns through **Prompts** (reusable templates for LLM interactions)
- And more!

## Core Concepts

### Server

The FastMCP server is your core interface to the MCP protocol. It handles connection management, protocol compliance, and message routing:

```python
# Add lifespan support for startup/shutdown with strong typing
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import AsyncIterator

from fake_database import Database  # Replace with your actual DB type

from mcp.server.fastmcp import Context, FastMCP

# Create a named server
mcp = FastMCP("My App")

# Specify dependencies for deployment and development
mcp = FastMCP("My App", dependencies=["pandas", "numpy"])


@dataclass
class AppContext:
    db: Database


@asynccontextmanager
async def app_lifespan(server: FastMCP) -> AsyncIterator[AppContext]:
    """Manage application lifecycle with type-safe context"""
    # Initialize on startup
    db = await Database.connect()
    try:
        yield AppContext(db=db)
    finally:
        # Cleanup on shutdown
        await db.disconnect()


# Pass lifespan to server
mcp = FastMCP("My App", lifespan=app_lifespan)


# Access type-safe lifespan context in tools
@mcp.tool()
def query_db(ctx: Context) -> str:
    """Tool that uses initialized resources"""
    db = ctx.request_context.lifespan_context["db"]
    return db.query()
```

### Resources

Resources are how you expose data to LLMs. They're similar to GET endpoints in a REST API - they provide data but shouldn't perform significant computation or have side effects:

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("My App")


@mcp.resource("config://app")
def get_config() -> str:
    """Static configuration data"""
    return "App configuration here"


@mcp.resource("users://{user_id}/profile")
def get_user_profile(user_id: str) -> str:
    """Dynamic user data"""
    return f"Profile data for user {user_id}"
```

### Tools

Tools let LLMs take actions through your server. Unlike resources, tools are expected to perform computation and have side effects:

```python
import httpx
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("My App")


@mcp.tool()
def calculate_bmi(weight_kg: float, height_m: float) -> float:
    """Calculate BMI given weight in kg and height in meters"""
    return weight_kg / (height_m**2)


@mcp.tool()
async def fetch_weather(city: str) -> str:
    """Fetch current weather for a city"""
    async with httpx.AsyncClient() as client:
        response = await client.get(f"https://api.weather.com/{city}")
        return response.text
```

### Prompts

Prompts are reusable templates that help LLMs interact with your server effectively:

```python
from mcp.server.fastmcp import FastMCP, types

mcp = FastMCP("My App")


@mcp.prompt()
def review_code(code: str) -> str:
    return f"Please review this code:\n\n{code}"


@mcp.prompt()
def debug_error(error: str) -> list[types.Message]:
    return [
        types.UserMessage("I'm seeing this error:"),
        types.UserMessage(error),
        types.AssistantMessage("I'll help debug that. What have you tried so far?"),
    ]
```

### Images

FastMCP provides an `Image` class that automatically handles image data:

```python
from mcp.server.fastmcp import FastMCP, Image
from PIL import Image as PILImage

mcp = FastMCP("My App")


@mcp.tool()
def create_thumbnail(image_path: str) -> Image:
    """Create a thumbnail from an image"""
    img = PILImage.open(image_path)
    img.thumbnail((100, 100))
    return Image(data=img.tobytes(), format="png")
```

### Context

The Context object gives your tools and resources access to MCP capabilities:

```python
from mcp.server.fastmcp import FastMCP, Context

mcp = FastMCP("My App")


@mcp.tool()
async def long_task(files: list[str], ctx: Context) -> str:
    """Process multiple files with progress tracking"""
    for i, file in enumerate(files):
        ctx.info(f"Processing {file}")
        await ctx.report_progress(i, len(files))
        data, mime_type = await ctx.read_resource(f"file://{file}")
    return "Processing complete"
```

## Running Your Server

### Development Mode

The fastest way to test and debug your server is with the MCP Inspector:

```bash
mcp dev server.py

# Add dependencies
mcp dev server.py --with pandas --with numpy

# Mount local code
mcp dev server.py --with-editable .
```

### Claude Desktop Integration

Once your server is ready, install it in Claude Desktop:

```bash
mcp install server.py

# Custom name
mcp install server.py --name "My Analytics Server"

# Environment variables
mcp install server.py -v API_KEY=abc123 -v DB_URL=postgres://...
mcp install server.py -f .env
```

### Direct Execution

For advanced scenarios like custom deployments:

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("My App")

if __name__ == "__main__":
    mcp.run()
```

Run it with:
```bash
python server.py
# or
mcp run server.py
```

## Examples

### Echo Server

A simple server demonstrating resources, tools, and prompts:

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("Echo")


@mcp.resource("echo://{message}")
def echo_resource(message: str) -> str:
    """Echo a message as a resource"""
    return f"Resource echo: {message}"


@mcp.tool()
def echo_tool(message: str) -> str:
    """Echo a message as a tool"""
    return f"Tool echo: {message}"


@mcp.prompt()
def echo_prompt(message: str) -> str:
    """Create an echo prompt"""
    return f"Please process this message: {message}"
```

### SQLite Explorer

A more complex example showing database integration:

```python
import sqlite3

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("SQLite Explorer")


@mcp.resource("schema://main")
def get_schema() -> str:
    """Provide the database schema as a resource"""
    conn = sqlite3.connect("database.db")
    schema = conn.execute("SELECT sql FROM sqlite_master WHERE type='table'").fetchall()
    return "\n".join(sql[0] for sql in schema if sql[0])


@mcp.tool()
def query_data(sql: str) -> str:
    """Execute SQL queries safely"""
    conn = sqlite3.connect("database.db")
    try:
        result = conn.execute(sql).fetchall()
        return "\n".join(str(row) for row in result)
    except Exception as e:
        return f"Error: {str(e)}"
```

## Advanced Usage

### Low-Level Server

For more control, you can use the low-level server implementation directly. This gives you full access to the protocol and allows you to customize every aspect of your server, including lifecycle management through the lifespan API:

```python
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fake_database import Database  # Replace with your actual DB type

from mcp.server import Server


@asynccontextmanager
async def server_lifespan(server: Server) -> AsyncIterator[dict]:
    """Manage server startup and shutdown lifecycle."""
    # Initialize resources on startup
    db = await Database.connect()
    try:
        yield {"db": db}
    finally:
        # Clean up on shutdown
        await db.disconnect()


# Pass lifespan to server
server = Server("example-server", lifespan=server_lifespan)


# Access lifespan context in handlers
@server.call_tool()
async def query_db(name: str, arguments: dict) -> list:
    ctx = server.request_context
    db = ctx.lifespan_context["db"]
    return await db.query(arguments["query"])
```

The lifespan API provides:
- A way to initialize resources when the server starts and clean them up when it stops
- Access to initialized resources through the request context in handlers
- Type-safe context passing between lifespan and request handlers

```python
import mcp.server.stdio
import mcp.types as types
from mcp.server.lowlevel import NotificationOptions, Server
from mcp.server.models import InitializationOptions

# Create a server instance
server = Server("example-server")


@server.list_prompts()
async def handle_list_prompts() -> list[types.Prompt]:
    return [
        types.Prompt(
            name="example-prompt",
            description="An example prompt template",
            arguments=[
                types.PromptArgument(
                    name="arg1", description="Example argument", required=True
                )
            ],
        )
    ]


@server.get_prompt()
async def handle_get_prompt(
    name: str, arguments: dict[str, str] | None
) -> types.GetPromptResult:
    if name != "example-prompt":
        raise ValueError(f"Unknown prompt: {name}")

    return types.GetPromptResult(
        description="Example prompt",
        messages=[
            types.PromptMessage(
                role="user",
                content=types.TextContent(type="text", text="Example prompt text"),
            )
        ],
    )


async def run():
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="example",
                server_version="0.1.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )


if __name__ == "__main__":
    import asyncio

    asyncio.run(run())
```

### Writing MCP Clients

The SDK provides a high-level client interface for connecting to MCP servers:

```python
from mcp import ClientSession, StdioServerParameters, types
from mcp.client.stdio import stdio_client

# Create server parameters for stdio connection
server_params = StdioServerParameters(
    command="python",  # Executable
    args=["example_server.py"],  # Optional command line arguments
    env=None,  # Optional environment variables
)


# Optional: create a sampling callback
async def handle_sampling_message(
    message: types.CreateMessageRequestParams,
) -> types.CreateMessageResult:
    return types.CreateMessageResult(
        role="assistant",
        content=types.TextContent(
            type="text",
            text="Hello, world! from model",
        ),
        model="gpt-3.5-turbo",
        stopReason="endTurn",
    )


async def run():
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(
            read, write, sampling_callback=handle_sampling_message
        ) as session:
            # Initialize the connection
            await session.initialize()

            # List available prompts
            prompts = await session.list_prompts()

            # Get a prompt
            prompt = await session.get_prompt(
                "example-prompt", arguments={"arg1": "value"}
            )

            # List available resources
            resources = await session.list_resources()

            # List available tools
            tools = await session.list_tools()

            # Read a resource
            content, mime_type = await session.read_resource("file://some/path")

            # Call a tool
            result = await session.call_tool("tool-name", arguments={"arg1": "value"})


if __name__ == "__main__":
    import asyncio

    asyncio.run(run())
```

### MCP Primitives

The MCP protocol defines three core primitives that servers can implement:

| Primitive | Control               | Description                                         | Example Use                  |
|-----------|-----------------------|-----------------------------------------------------|------------------------------|
| Prompts   | User-controlled       | Interactive templates invoked by user choice        | Slash commands, menu options |
| Resources | Application-controlled| Contextual data managed by the client application   | File contents, API responses |
| Tools     | Model-controlled      | Functions exposed to the LLM to take actions        | API calls, data updates      |

### Server Capabilities

MCP servers declare capabilities during initialization:

| Capability  | Feature Flag                 | Description                        |
|-------------|------------------------------|------------------------------------|
| `prompts`   | `listChanged`                | Prompt template management         |
| `resources` | `subscribe`<br/>`listChanged`| Resource exposure and updates      |
| `tools`     | `listChanged`                | Tool discovery and execution       |
| `logging`   | -                            | Server logging configuration       |
| `completion`| -                            | Argument completion suggestions    |

## Documentation

- [Model Context Protocol documentation](https://modelcontextprotocol.io)
- [Model Context Protocol specification](https://spec.modelcontextprotocol.io)
- [Officially supported servers](https://github.com/modelcontextprotocol/servers)

## Contributing

We are passionate about supporting contributors of all levels of experience and would love to see you get involved in the project. See the [contributing guide](CONTRIBUTING.md) to get started.

## License

This project is licensed under the MIT License - see the LICENSE file for details.


# Examples

Here is a dump of all the code examples files of the Python SDK in the format:
```bash
echo "==== File: $relative_path ====" >> "$output_file"
echo "" >> "$output_file"
cat "$file" >> "$output_file"
echo "" >> "$output_file"
echo "" >> "$output_file"
```

examples:
```
==== File: simple-prompt/README.md ====

# MCP Simple Prompt

A simple MCP server that exposes a customizable prompt template with optional context and topic parameters.

## Usage

Start the server using either stdio (default) or SSE transport:

```bash
# Using stdio transport (default)
uv run mcp-simple-prompt

# Using SSE transport on custom port
uv run mcp-simple-prompt --transport sse --port 8000
```

The server exposes a prompt named "simple" that accepts two optional arguments:

- `context`: Additional context to consider
- `topic`: Specific topic to focus on

## Example

Using the MCP client, you can retrieve the prompt like this using the STDIO transport:

```python
import asyncio
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client


async def main():
    async with stdio_client(
        StdioServerParameters(command="uv", args=["run", "mcp-simple-prompt"])
    ) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # List available prompts
            prompts = await session.list_prompts()
            print(prompts)

            # Get the prompt with arguments
            prompt = await session.get_prompt(
                "simple",
                {
                    "context": "User is a software developer",
                    "topic": "Python async programming",
                },
            )
            print(prompt)


asyncio.run(main())
```


==== File: simple-prompt/mcp_simple_prompt/__init__.py ====




==== File: simple-prompt/mcp_simple_prompt/__main__.py ====

import sys

from .server import main

sys.exit(main())


==== File: simple-prompt/mcp_simple_prompt/server.py ====

import anyio
import click
import mcp.types as types
from mcp.server.lowlevel import Server


def create_messages(
context: str | None = None, topic: str | None = None
) -> list[types.PromptMessage]:
"""Create the messages for the prompt."""
messages = []

    # Add context if provided
    if context:
        messages.append(
            types.PromptMessage(
                role="user",
                content=types.TextContent(
                    type="text", text=f"Here is some relevant context: {context}"
                ),
            )
        )

    # Add the main prompt
    prompt = "Please help me with "
    if topic:
        prompt += f"the following topic: {topic}"
    else:
        prompt += "whatever questions I may have."

    messages.append(
        types.PromptMessage(
            role="user", content=types.TextContent(type="text", text=prompt)
        )
    )

    return messages


@click.command()
@click.option("--port", default=8000, help="Port to listen on for SSE")
@click.option(
"--transport",
type=click.Choice(["stdio", "sse"]),
default="stdio",
help="Transport type",
)
def main(port: int, transport: str) -> int:
app = Server("mcp-simple-prompt")

    @app.list_prompts()
    async def list_prompts() -> list[types.Prompt]:
        return [
            types.Prompt(
                name="simple",
                description="A simple prompt that can take optional context and topic "
                "arguments",
                arguments=[
                    types.PromptArgument(
                        name="context",
                        description="Additional context to consider",
                        required=False,
                    ),
                    types.PromptArgument(
                        name="topic",
                        description="Specific topic to focus on",
                        required=False,
                    ),
                ],
            )
        ]

    @app.get_prompt()
    async def get_prompt(
        name: str, arguments: dict[str, str] | None = None
    ) -> types.GetPromptResult:
        if name != "simple":
            raise ValueError(f"Unknown prompt: {name}")

        if arguments is None:
            arguments = {}

        return types.GetPromptResult(
            messages=create_messages(
                context=arguments.get("context"), topic=arguments.get("topic")
            ),
            description="A simple prompt with optional context and topic arguments",
        )

    if transport == "sse":
        from mcp.server.sse import SseServerTransport
        from starlette.applications import Starlette
        from starlette.routing import Mount, Route

        sse = SseServerTransport("/messages/")

        async def handle_sse(request):
            async with sse.connect_sse(
                request.scope, request.receive, request._send
            ) as streams:
                await app.run(
                    streams[0], streams[1], app.create_initialization_options()
                )

        starlette_app = Starlette(
            debug=True,
            routes=[
                Route("/sse", endpoint=handle_sse),
                Mount("/messages/", app=sse.handle_post_message),
            ],
        )

        import uvicorn

        uvicorn.run(starlette_app, host="0.0.0.0", port=port)
    else:
        from mcp.server.stdio import stdio_server

        async def arun():
            async with stdio_server() as streams:
                await app.run(
                    streams[0], streams[1], app.create_initialization_options()
                )

        anyio.run(arun)

    return 0


==== File: simple-resource/README.md ====

# MCP Simple Resource

A simple MCP server that exposes sample text files as resources.

## Usage

Start the server using either stdio (default) or SSE transport:

```bash
# Using stdio transport (default)
uv run mcp-simple-resource

# Using SSE transport on custom port
uv run mcp-simple-resource --transport sse --port 8000
```

The server exposes some basic text file resources that can be read by clients.

## Example

Using the MCP client, you can retrieve resources like this using the STDIO transport:

```python
import asyncio
from mcp.types import AnyUrl
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client


async def main():
    async with stdio_client(
        StdioServerParameters(command="uv", args=["run", "mcp-simple-resource"])
    ) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # List available resources
            resources = await session.list_resources()
            print(resources)

            # Get a specific resource
            resource = await session.read_resource(AnyUrl("file:///greeting.txt"))
            print(resource)


asyncio.run(main())

```


==== File: simple-resource/mcp_simple_resource/__init__.py ====




==== File: simple-resource/mcp_simple_resource/__main__.py ====

import sys

from server import main

sys.exit(main())


==== File: simple-resource/mcp_simple_resource/server.py ====

import anyio
import click
import mcp.types as types
from mcp.server.lowlevel import Server
from pydantic import FileUrl

SAMPLE_RESOURCES = {
"greeting": "Hello! This is a sample text resource.",
"help": "This server provides a few sample text resources for testing.",
"about": "This is the simple-resource MCP server implementation.",
}


@click.command()
@click.option("--port", default=8000, help="Port to listen on for SSE")
@click.option(
"--transport",
type=click.Choice(["stdio", "sse"]),
default="stdio",
help="Transport type",
)
def main(port: int, transport: str) -> int:
app = Server("mcp-simple-resource")

    @app.list_resources()
    async def list_resources() -> list[types.Resource]:
        return [
            types.Resource(
                uri=FileUrl(f"file:///{name}.txt"),
                name=name,
                description=f"A sample text resource named {name}",
                mimeType="text/plain",
            )
            for name in SAMPLE_RESOURCES.keys()
        ]

    @app.read_resource()
    async def read_resource(uri: FileUrl) -> str | bytes:
        name = uri.path.replace(".txt", "").lstrip("/")

        if name not in SAMPLE_RESOURCES:
            raise ValueError(f"Unknown resource: {uri}")

        return SAMPLE_RESOURCES[name]

    if transport == "sse":
        from mcp.server.sse import SseServerTransport
        from starlette.applications import Starlette
        from starlette.routing import Mount, Route

        sse = SseServerTransport("/messages/")

        async def handle_sse(request):
            async with sse.connect_sse(
                request.scope, request.receive, request._send
            ) as streams:
                await app.run(
                    streams[0], streams[1], app.create_initialization_options()
                )

        starlette_app = Starlette(
            debug=True,
            routes=[
                Route("/sse", endpoint=handle_sse),
                Mount("/messages/", app=sse.handle_post_message),
            ],
        )

        import uvicorn

        uvicorn.run(starlette_app, host="0.0.0.0", port=port)
    else:
        from mcp.server.stdio import stdio_server

        async def arun():
            async with stdio_server() as streams:
                await app.run(
                    streams[0], streams[1], app.create_initialization_options()
                )

        anyio.run(arun)

    return 0


==== File: simple-tool/README.md ====


A simple MCP server that exposes a website fetching tool.

## Usage

Start the server using either stdio (default) or SSE transport:

```bash
# Using stdio transport (default)
uv run mcp-simple-tool

# Using SSE transport on custom port
uv run mcp-simple-tool --transport sse --port 8000
```

The server exposes a tool named "fetch" that accepts one required argument:

- `url`: The URL of the website to fetch

## Example

Using the MCP client, you can use the tool like this using the STDIO transport:

```python
import asyncio
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client


async def main():
    async with stdio_client(
        StdioServerParameters(command="uv", args=["run", "mcp-simple-tool"])
    ) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # List available tools
            tools = await session.list_tools()
            print(tools)

            # Call the fetch tool
            result = await session.call_tool("fetch", {"url": "https://example.com"})
            print(result)


asyncio.run(main())

```


==== File: simple-tool/mcp_simple_tool/__init__.py ====




==== File: simple-tool/mcp_simple_tool/__main__.py ====

import sys

from server import main

sys.exit(main())


==== File: simple-tool/mcp_simple_tool/server.py ====

import anyio
import click
import httpx
import mcp.types as types
from mcp.server.lowlevel import Server


async def fetch_website(
url: str,
) -> list[types.TextContent | types.ImageContent | types.EmbeddedResource]:
headers = {
"User-Agent": "MCP Test Server (github.com/modelcontextprotocol/python-sdk)"
}
async with httpx.AsyncClient(follow_redirects=True, headers=headers) as client:
response = await client.get(url)
response.raise_for_status()
return [types.TextContent(type="text", text=response.text)]


@click.command()
@click.option("--port", default=8000, help="Port to listen on for SSE")
@click.option(
"--transport",
type=click.Choice(["stdio", "sse"]),
default="stdio",
help="Transport type",
)
def main(port: int, transport: str) -> int:
app = Server("mcp-website-fetcher")

    @app.call_tool()
    async def fetch_tool(
        name: str, arguments: dict
    ) -> list[types.TextContent | types.ImageContent | types.EmbeddedResource]:
        if name != "fetch":
            raise ValueError(f"Unknown tool: {name}")
        if "url" not in arguments:
            raise ValueError("Missing required argument 'url'")
        return await fetch_website(arguments["url"])

    @app.list_tools()
    async def list_tools() -> list[types.Tool]:
        return [
            types.Tool(
                name="fetch",
                description="Fetches a website and returns its content",
                inputSchema={
                    "type": "object",
                    "required": ["url"],
                    "properties": {
                        "url": {
                            "type": "string",
                            "description": "URL to fetch",
                        }
                    },
                },
            )
        ]

    if transport == "sse":
        from mcp.server.sse import SseServerTransport
        from starlette.applications import Starlette
        from starlette.routing import Mount, Route

        sse = SseServerTransport("/messages/")

        async def handle_sse(request):
            async with sse.connect_sse(
                request.scope, request.receive, request._send
            ) as streams:
                await app.run(
                    streams[0], streams[1], app.create_initialization_options()
                )

        starlette_app = Starlette(
            debug=True,
            routes=[
                Route("/sse", endpoint=handle_sse),
                Mount("/messages/", app=sse.handle_post_message),
            ],
        )

        import uvicorn

        uvicorn.run(starlette_app, host="0.0.0.0", port=port)
    else:
        from mcp.server.stdio import stdio_server

        async def arun():
            async with stdio_server() as streams:
                await app.run(
                    streams[0], streams[1], app.create_initialization_options()
                )

        anyio.run(arun)

    return 0

```


Fast MCP Examples:

```
==== File: complex_inputs.py ====

"""
FastMCP Complex inputs Example

Demonstrates validation via pydantic with complex models.
"""

from typing import Annotated

from pydantic import BaseModel, Field

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("Shrimp Tank")


class ShrimpTank(BaseModel):
class Shrimp(BaseModel):
name: Annotated[str, Field(max_length=10)]

    shrimp: list[Shrimp]


@mcp.tool()
def name_shrimp(
tank: ShrimpTank,
# You can use pydantic Field in function signatures for validation.
extra_names: Annotated[list[str], Field(max_length=10)],
) -> list[str]:
"""List all shrimp names in the tank"""
return [shrimp.name for shrimp in tank.shrimp] + extra_names


==== File: desktop.py ====

"""
FastMCP Desktop Example

A simple example that exposes the desktop directory as a resource.
"""

from pathlib import Path

from mcp.server.fastmcp import FastMCP

# Create server
mcp = FastMCP("Demo")


@mcp.resource("dir://desktop")
def desktop() -> list[str]:
"""List the files in the user's desktop"""
desktop = Path.home() / "Desktop"
return [str(f) for f in desktop.iterdir()]


@mcp.tool()
def add(a: int, b: int) -> int:
"""Add two numbers"""
return a + b


==== File: echo.py ====

"""
FastMCP Echo Server
"""

from mcp.server.fastmcp import FastMCP

# Create server
mcp = FastMCP("Echo Server")


@mcp.tool()
def echo_tool(text: str) -> str:
"""Echo the input text"""
return text


@mcp.resource("echo://static")
def echo_resource() -> str:
return "Echo!"


@mcp.resource("echo://{text}")
def echo_template(text: str) -> str:
"""Echo the input text"""
return f"Echo: {text}"


@mcp.prompt("echo")
def echo_prompt(text: str) -> str:
return text


==== File: memory.py ====

# /// script
# dependencies = ["pydantic-ai-slim[openai]", "asyncpg", "numpy", "pgvector"]
# ///

# uv pip install 'pydantic-ai-slim[openai]' asyncpg numpy pgvector

"""
Recursive memory system inspired by the human brain's clustering of memories.
Uses OpenAI's 'text-embedding-3-small' model and pgvector for efficient
similarity search.
"""

import asyncio
import math
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated, Self

import asyncpg
import numpy as np
from openai import AsyncOpenAI
from pgvector.asyncpg import register_vector  # Import register_vector
from pydantic import BaseModel, Field
from pydantic_ai import Agent

from mcp.server.fastmcp import FastMCP

MAX_DEPTH = 5
SIMILARITY_THRESHOLD = 0.7
DECAY_FACTOR = 0.99
REINFORCEMENT_FACTOR = 1.1

DEFAULT_LLM_MODEL = "openai:gpt-4o"
DEFAULT_EMBEDDING_MODEL = "text-embedding-3-small"

mcp = FastMCP(
"memory",
dependencies=[
"pydantic-ai-slim[openai]",
"asyncpg",
"numpy",
"pgvector",
],
)

DB_DSN = "postgresql://postgres:postgres@localhost:54320/memory_db"
# reset memory with rm ~/.fastmcp/{USER}/memory/*
PROFILE_DIR = (
Path.home() / ".fastmcp" / os.environ.get("USER", "anon") / "memory"
).resolve()
PROFILE_DIR.mkdir(parents=True, exist_ok=True)


def cosine_similarity(a: list[float], b: list[float]) -> float:
a_array = np.array(a, dtype=np.float64)
b_array = np.array(b, dtype=np.float64)
return np.dot(a_array, b_array) / (
np.linalg.norm(a_array) * np.linalg.norm(b_array)
)


async def do_ai[T](
user_prompt: str,
system_prompt: str,
result_type: type[T] | Annotated,
deps=None,
) -> T:
agent = Agent(
DEFAULT_LLM_MODEL,
system_prompt=system_prompt,
result_type=result_type,
)
result = await agent.run(user_prompt, deps=deps)
return result.data


@dataclass
class Deps:
openai: AsyncOpenAI
pool: asyncpg.Pool


async def get_db_pool() -> asyncpg.Pool:
async def init(conn):
await conn.execute("CREATE EXTENSION IF NOT EXISTS vector;")
await register_vector(conn)

    pool = await asyncpg.create_pool(DB_DSN, init=init)
    return pool


class MemoryNode(BaseModel):
id: int | None = None
content: str
summary: str = ""
importance: float = 1.0
access_count: int = 0
timestamp: float = Field(
default_factory=lambda: datetime.now(timezone.utc).timestamp()
)
embedding: list[float]

    @classmethod
    async def from_content(cls, content: str, deps: Deps):
        embedding = await get_embedding(content, deps)
        return cls(content=content, embedding=embedding)

    async def save(self, deps: Deps):
        async with deps.pool.acquire() as conn:
            if self.id is None:
                result = await conn.fetchrow(
                    """
                    INSERT INTO memories (content, summary, importance, access_count,
                        timestamp, embedding)
                    VALUES ($1, $2, $3, $4, $5, $6)
                    RETURNING id
                    """,
                    self.content,
                    self.summary,
                    self.importance,
                    self.access_count,
                    self.timestamp,
                    self.embedding,
                )
                self.id = result["id"]
            else:
                await conn.execute(
                    """
                    UPDATE memories
                    SET content = $1, summary = $2, importance = $3,
                        access_count = $4, timestamp = $5, embedding = $6
                    WHERE id = $7
                    """,
                    self.content,
                    self.summary,
                    self.importance,
                    self.access_count,
                    self.timestamp,
                    self.embedding,
                    self.id,
                )

    async def merge_with(self, other: Self, deps: Deps):
        self.content = await do_ai(
            f"{self.content}\n\n{other.content}",
            "Combine the following two texts into a single, coherent text.",
            str,
            deps,
        )
        self.importance += other.importance
        self.access_count += other.access_count
        self.embedding = [(a + b) / 2 for a, b in zip(self.embedding, other.embedding)]
        self.summary = await do_ai(
            self.content, "Summarize the following text concisely.", str, deps
        )
        await self.save(deps)
        # Delete the merged node from the database
        if other.id is not None:
            await delete_memory(other.id, deps)

    def get_effective_importance(self):
        return self.importance * (1 + math.log(self.access_count + 1))


async def get_embedding(text: str, deps: Deps) -> list[float]:
embedding_response = await deps.openai.embeddings.create(
input=text,
model=DEFAULT_EMBEDDING_MODEL,
)
return embedding_response.data[0].embedding


async def delete_memory(memory_id: int, deps: Deps):
async with deps.pool.acquire() as conn:
await conn.execute("DELETE FROM memories WHERE id = $1", memory_id)


async def add_memory(content: str, deps: Deps):
new_memory = await MemoryNode.from_content(content, deps)
await new_memory.save(deps)

    similar_memories = await find_similar_memories(new_memory.embedding, deps)
    for memory in similar_memories:
        if memory.id != new_memory.id:
            await new_memory.merge_with(memory, deps)

    await update_importance(new_memory.embedding, deps)

    await prune_memories(deps)

    return f"Remembered: {content}"


async def find_similar_memories(embedding: list[float], deps: Deps) -> list[MemoryNode]:
async with deps.pool.acquire() as conn:
rows = await conn.fetch(
"""
SELECT id, content, summary, importance, access_count, timestamp, embedding
FROM memories
ORDER BY embedding <-> $1
LIMIT 5
""",
embedding,
)
memories = [
MemoryNode(
id=row["id"],
content=row["content"],
summary=row["summary"],
importance=row["importance"],
access_count=row["access_count"],
timestamp=row["timestamp"],
embedding=row["embedding"],
)
for row in rows
]
return memories


async def update_importance(user_embedding: list[float], deps: Deps):
async with deps.pool.acquire() as conn:
rows = await conn.fetch(
"SELECT id, importance, access_count, embedding FROM memories"
)
for row in rows:
memory_embedding = row["embedding"]
similarity = cosine_similarity(user_embedding, memory_embedding)
if similarity > SIMILARITY_THRESHOLD:
new_importance = row["importance"] * REINFORCEMENT_FACTOR
new_access_count = row["access_count"] + 1
else:
new_importance = row["importance"] * DECAY_FACTOR
new_access_count = row["access_count"]
await conn.execute(
"""
UPDATE memories
SET importance = $1, access_count = $2
WHERE id = $3
""",
new_importance,
new_access_count,
row["id"],
)


async def prune_memories(deps: Deps):
async with deps.pool.acquire() as conn:
rows = await conn.fetch(
"""
SELECT id, importance, access_count
FROM memories
ORDER BY importance DESC
OFFSET $1
""",
MAX_DEPTH,
)
for row in rows:
await conn.execute("DELETE FROM memories WHERE id = $1", row["id"])


async def display_memory_tree(deps: Deps) -> str:
async with deps.pool.acquire() as conn:
rows = await conn.fetch(
"""
SELECT content, summary, importance, access_count
FROM memories
ORDER BY importance DESC
LIMIT $1
""",
MAX_DEPTH,
)
result = ""
for row in rows:
effective_importance = row["importance"] * (
1 + math.log(row["access_count"] + 1)
)
summary = row["summary"] or row["content"]
result += f"- {summary} (Importance: {effective_importance:.2f})\n"
return result


@mcp.tool()
async def remember(
contents: list[str] = Field(
description="List of observations or memories to store"
),
):
deps = Deps(openai=AsyncOpenAI(), pool=await get_db_pool())
try:
return "\n".join(
await asyncio.gather(*[add_memory(content, deps) for content in contents])
)
finally:
await deps.pool.close()


@mcp.tool()
async def read_profile() -> str:
deps = Deps(openai=AsyncOpenAI(), pool=await get_db_pool())
profile = await display_memory_tree(deps)
await deps.pool.close()
return profile


async def initialize_database():
pool = await asyncpg.create_pool(
"postgresql://postgres:postgres@localhost:54320/postgres"
)
try:
async with pool.acquire() as conn:
await conn.execute("""
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'memory_db'
AND pid <> pg_backend_pid();
""")
await conn.execute("DROP DATABASE IF EXISTS memory_db;")
await conn.execute("CREATE DATABASE memory_db;")
finally:
await pool.close()

    pool = await asyncpg.create_pool(DB_DSN)
    try:
        async with pool.acquire() as conn:
            await conn.execute("CREATE EXTENSION IF NOT EXISTS vector;")

            await register_vector(conn)

            await conn.execute("""
                CREATE TABLE IF NOT EXISTS memories (
                    id SERIAL PRIMARY KEY,
                    content TEXT NOT NULL,
                    summary TEXT,
                    importance REAL NOT NULL,
                    access_count INT NOT NULL,
                    timestamp DOUBLE PRECISION NOT NULL,
                    embedding vector(1536) NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_memories_embedding ON memories
                    USING hnsw (embedding vector_l2_ops);
            """)
    finally:
        await pool.close()


if __name__ == "__main__":
asyncio.run(initialize_database())


==== File: parameter_descriptions.py ====

"""
FastMCP Example showing parameter descriptions
"""

from pydantic import Field

from mcp.server.fastmcp import FastMCP

# Create server
mcp = FastMCP("Parameter Descriptions Server")


@mcp.tool()
def greet_user(
name: str = Field(description="The name of the person to greet"),
title: str = Field(description="Optional title like Mr/Ms/Dr", default=""),
times: int = Field(description="Number of times to repeat the greeting", default=1),
) -> str:
"""Greet a user with optional title and repetition"""
greeting = f"Hello {title + ' ' if title else ''}{name}!"
return "\n".join([greeting] * times)


==== File: readme-quickstart.py ====

from mcp.server.fastmcp import FastMCP

# Create an MCP server
mcp = FastMCP("Demo")


# Add an addition tool
@mcp.tool()
def add(a: int, b: int) -> int:
"""Add two numbers"""
return a + b


# Add a dynamic greeting resource
@mcp.resource("greeting://{name}")
def get_greeting(name: str) -> str:
"""Get a personalized greeting"""
return f"Hello, {name}!"


==== File: screenshot.py ====

"""
FastMCP Screenshot Example

Give Claude a tool to capture and view screenshots.
"""

import io

from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.utilities.types import Image

# Create server
mcp = FastMCP("Screenshot Demo", dependencies=["pyautogui", "Pillow"])


@mcp.tool()
def take_screenshot() -> Image:
"""
Take a screenshot of the user's screen and return it as an image. Use
this tool anytime the user wants you to look at something they're doing.
"""
import pyautogui

    buffer = io.BytesIO()

    # if the file exceeds ~1MB, it will be rejected by Claude
    screenshot = pyautogui.screenshot()
    screenshot.convert("RGB").save(buffer, format="JPEG", quality=60, optimize=True)
    return Image(data=buffer.getvalue(), format="jpeg")


==== File: simple_echo.py ====

"""
FastMCP Echo Server
"""

from mcp.server.fastmcp import FastMCP

# Create server
mcp = FastMCP("Echo Server")


@mcp.tool()
def echo(text: str) -> str:
"""Echo the input text"""
return text


==== File: text_me.py ====

# /// script
# dependencies = []
# ///

"""
FastMCP Text Me Server
--------------------------------
This defines a simple FastMCP server that sends a text message to a phone number via https://surgemsg.com/.

To run this example, create a `.env` file with the following values:

SURGE_API_KEY=...
SURGE_ACCOUNT_ID=...
SURGE_MY_PHONE_NUMBER=...
SURGE_MY_FIRST_NAME=...
SURGE_MY_LAST_NAME=...

Visit https://surgemsg.com/ and click "Get Started" to obtain these values.
"""

from typing import Annotated

import httpx
from pydantic import BeforeValidator
from pydantic_settings import BaseSettings, SettingsConfigDict

from mcp.server.fastmcp import FastMCP


class SurgeSettings(BaseSettings):
model_config: SettingsConfigDict = SettingsConfigDict(
env_prefix="SURGE_", env_file=".env"
)

    api_key: str
    account_id: str
    my_phone_number: Annotated[
        str, BeforeValidator(lambda v: "+" + v if not v.startswith("+") else v)
    ]
    my_first_name: str
    my_last_name: str


# Create server
mcp = FastMCP("Text me")
surge_settings = SurgeSettings()  # type: ignore


@mcp.tool(name="textme", description="Send a text message to me")
def text_me(text_content: str) -> str:
"""Send a text message to a phone number via https://surgemsg.com/"""
with httpx.Client() as client:
response = client.post(
"https://api.surgemsg.com/messages",
headers={
"Authorization": f"Bearer {surge_settings.api_key}",
"Surge-Account": surge_settings.account_id,
"Content-Type": "application/json",
},
json={
"body": text_content,
"conversation": {
"contact": {
"first_name": surge_settings.my_first_name,
"last_name": surge_settings.my_last_name,
"phone_number": surge_settings.my_phone_number,
}
},
},
)
response.raise_for_status()
return f"Message sent: {text_content}"


==== File: unicode_example.py ====

"""
Example FastMCP server that uses Unicode characters in various places to help test
Unicode handling in tools and inspectors.
"""

from mcp.server.fastmcp import FastMCP

mcp = FastMCP()


@mcp.tool(
description="🌟 A tool that uses various Unicode characters in its description: "
"á é í ó ú ñ 漢字 🎉"
)
def hello_unicode(name: str = "世界", greeting: str = "¡Hola") -> str:
"""
A simple tool that demonstrates Unicode handling in:
- Tool description (emojis, accents, CJK characters)
- Parameter defaults (CJK characters)
- Return values (Spanish punctuation, emojis)
"""
return f"{greeting}, {name}! 👋"


@mcp.tool(description="🎨 Tool that returns a list of emoji categories")
def list_emoji_categories() -> list[str]:
"""Returns a list of emoji categories with emoji examples."""
return [
"😀 Smileys & Emotion",
"👋 People & Body",
"🐶 Animals & Nature",
"🍎 Food & Drink",
"⚽ Activities",
"🌍 Travel & Places",
"💡 Objects",
"❤️ Symbols",
"🚩 Flags",
]


@mcp.tool(description="🔤 Tool that returns text in different scripts")
def multilingual_hello() -> str:
"""Returns hello in different scripts and writing systems."""
return "\n".join(
[
"English: Hello!",
"Spanish: ¡Hola!",
"French: Bonjour!",
"German: Grüß Gott!",
"Russian: Привет!",
"Greek: Γεια σας!",
"Hebrew: !שָׁלוֹם",
"Arabic: !مرحبا",
"Hindi: नमस्ते!",
"Chinese: 你好!",
"Japanese: こんにちは!",
"Korean: 안녕하세요!",
"Thai: สวัสดี!",
]
)


if __name__ == "__main__":
mcp.run()


```
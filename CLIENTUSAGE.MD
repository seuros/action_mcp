# ActionMCP::Client Usage

This document provides examples of how to use the `ActionMCP::Client` class to connect to and interact with MCP servers.

## Creating a Client

The `ActionMCP::Client` is the main entry point for interacting with MCP servers. 
You can create a client using the `ActionMCP.create_client` method. 
This method automatically determines the appropriate transport for your endpoint. STDIO transport is not supported.

```ruby
# Create client with default StreamableHTTP transport
client = ActionMCP.create_client("http://127.0.0.1:62770")
```

### create_client method

The `create_client` method accepts the following arguments:

*   `endpoint` (String): The endpoint to connect to (URL). Only remote HTTP(S) endpoints are supported.
*   `logger` (Logger): The logger to use. Default is `Logger.new($stdout)`.
*   `options` (Hash): Additional options to pass to the client constructor, including:
    *   `session_store` (Symbol): Session storage backend (`:memory` or `:active_record`)
    *   `session_id` (String): Optional session ID for resuming existing sessions (auto-generated if not provided)
    *   `connect` (Boolean): Whether to connect immediately (default: true)

### Session Management

Sessions are created and managed by the MCP server. The server provides a session ID in the `Mcp-Session-Id` HTTP header of the initialize response, which the client stores for future use.

```ruby
# Development with memory sessions (default)
# Server will create a new session and provide the ID in response header
client = ActionMCP.create_client("http://localhost:62770")

# Production with persistent sessions
# Server will create a new session and provide the ID in response header
client = ActionMCP.create_client(
  "http://localhost:62770",
  session_store: :active_record
)

# Resume an existing session by providing the session ID
# The client includes the session ID in the Mcp-Session-Id header
# The server will recognize the session and skip re-initialization
client = ActionMCP.create_client(
  "http://localhost:62770",
  session_store: :active_record,
  session_id: "abc123def456"  # Previously received from server
)

# The client automatically stores the session ID after successful initialization
# You can access it for future resumption:
client.connect
session_id = client.session.id  # Store this for later use
```

## Transport System

ActionMCP uses a pluggable transport system. The default transport is StreamableHTTP, which implements the full MCP StreamableHTTP specification. Legacy SSE transport is also available for backward compatibility.

### Session ID Protocol

The session ID is exchanged via the `Mcp-Session-Id` HTTP header:
- **Client → Server**: When resuming a session, include the session ID in the request header
- **Server → Client**: Server provides the session ID in the response header for new sessions
- All subsequent requests must include the session ID header (except the initial `initialize` request)

### Connecting to the Server

To connect to the server, call the `connect` method:

```ruby
# Create client without connecting
client = ActionMCP.create_client("http://127.0.0.1:62770", connect: false)

# Connect when ready
client.connect
```

### Checking Connection Status

You can check if the client is connected to the server using the `connected?` method:

```ruby
client.connected? # => true or false
```

You can check if the client is ready to send messages using the `ready?` method:

```ruby
client.ready? # => true or false
```

### Session Resumability

The transport system supports automatic session resumption for both reconnections and new client instances:

```ruby
# Initial connection - server creates session
client = ActionMCP.create_client(
  "http://localhost:62770",
  session_store: :active_record
)
client.connect
session_id = client.session.id  # e.g., "abc123def456"

# Later, create a new client that resumes the same session
resumed_client = ActionMCP.create_client(
  "http://localhost:62770",
  session_store: :active_record,
  session_id: session_id
)
# Server recognizes the session and skips re-initialization

# The transport also handles automatic reconnection with SSE resumption
# using last-event-id for seamless continuity
```


## Additional operations

### Accessing Tool, Prompt, Resource and Blueprint Collections

The `ActionMCP::Client` provides access to collections of tools, prompts, resources, and blueprints through the following attributes:

*   `.toolbox`: A `Toolbox` instance for managing tools.
*   `.prompt_book`: A `PromptBook` instance for managing prompts.
*   `.catalog`: A `Catalog` instance for managing resources.
*   `.blueprint`: A `Blueprint` instance for managing resource templates.

### Fetching tools from the toolbox

```ruby
tools = client.toolbox.all
tools.each do |tool|
  puts tool.name
end
```

### Accessing prompts from the prompt_book

```ruby
prompts = client.prompt_book.all
prompts.each do |prompt|
  puts prompt.name
end
```

### Accessing resources from the catalog

```ruby
resources = client.catalog.all
resources.each do |resource|
  puts resource.uri
end
```

### Accessing blueprints from the blueprint

```ruby
blueprints = client.blueprint.all
blueprints.each do |blueprint|
  puts blueprint.pattern
end
```

## Conclusion

This document provides a basic overview of how to use the `ActionMCP::Client` class. 
For more information, please refer to the official documentation by reading the source.

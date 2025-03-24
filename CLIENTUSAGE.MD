# ActionMCP::Client Usage

This document provides examples of how to use the `ActionMCP::Client` class to connect to and interact with MCP servers.

## Creating a Client

The `ActionMCP::Client` is the main entry point for interacting with MCP servers. 
You can create a client using the `ActionMCP.create_client` method. 
This method automatically determines whether to create an `SSEClient` or a `StdioClient` based on the endpoint.

```ruby
client = ActionMCP.create_client("http://127.0.0.1:3066/action_mcp")
```

or

```ruby
client = ActionMCP.create_client("some_command")
```

### create_client method

The `create_client` method accepts the following arguments:

*   `endpoint` (String): The endpoint to connect to (URL or command). If the endpoint is a URL (starts with `http://` or `https://`), an `SSEClient` is created. Otherwise, a `StdioClient` is created.
*   `logger` (Logger): The logger to use. Default is `Logger.new($stdout)`.
*   `options` (Hash): Additional options to pass to the client constructor.

## SSEClient Usage

The `SSEClient` is used to connect to MCP servers via HTTP Server-Sent Events.

### Connecting to the Server

To connect to the server, call the `connect` method:

```ruby
client = ActionMCP.create_client("http://127.0.0.1:3066/action_mcp", connect: false)
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

## StdioClient Usage

The `StdioClient` is used to connect to MCP servers via standard input/output, this is not well tested.

### Starting the Transport

To start the transport, call the `start_transport` method:

```ruby
client = ActionMCP.create_client("some_command")
client.connect
```

### Checking Connection Status

You can check if the client is connected to the server using the `connected?` method:

```ruby
client.connected? # => true or false
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

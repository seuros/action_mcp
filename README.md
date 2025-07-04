# ActionMCP

**ActionMCP** is a Ruby gem focused on providing Model Context Protocol (MCP) capability to Ruby on Rails applications, specifically as a server.

ActionMCP is designed for production Rails environments and does **not** support STDIO transport. STDIO is not included because it is not production-ready and is only suitable for desktop or script-based use cases. Instead, ActionMCP is built for robust, network-based deployments.

The client functionality in ActionMCP is intended to connect to remote MCP servers, not to local processes via STDIO.

It offers base classes and helpers for creating MCP applications, making it easier to integrate your Ruby/Rails application with the MCP standard.

With ActionMCP, you can focus on your app's logic while it handles the boilerplate for MCP compliance.

## Introduction

**Model Context Protocol (MCP)** is an open protocol that standardizes how applications provide context to large language models (LLMs).

Think of it as a universal interface for connecting AI assistants to external data sources and tools.

MCP allows AI systems to plug into various resources in a consistent, secure way, enabling two-way integration between your data and AI-powered applications.

This means an AI (like an LLM) can request information or actions from your application through a well-defined protocol, and your app can provide context or perform tasks for the AI in return.

**ActionMCP** is targeted at developers building MCP-enabled Rails applications. It simplifies the process of integrating Ruby and Rails apps with the MCP standard by providing a set of base classes and an easy-to-use server interface.

## Protocol Support

ActionMCP supports **MCP 2025-06-18** (current) with backward compatibility for **MCP 2025-03-26**. For a detailed (and entertaining) breakdown of protocol versions, features, and our design decisions, see [The Hitchhiker's Guide to MCP](The_Hitchhikers_Guide_to_MCP.md).

*Don't Panic: The guide contains everything you need to know about surviving MCP protocol versions.*

> **Note:** STDIO transport is not supported in ActionMCP. This gem is focused on production-ready, network-based deployments. STDIO is only suitable for desktop or script-based experimentation and is intentionally excluded.

Instead of implementing MCP support from scratch, you can subclass and configure the provided **Prompt**, **Tool**, and **ResourceTemplate** classes to expose your app's functionality to LLMs. 

ActionMCP handles the underlying MCP message format and routing, so you can adhere to the open standard with minimal effort.

In short, ActionMCP helps you build an MCP server (the component that exposes capabilities to AI) more quickly and with fewer mistakes.

> **Client connections:** The client part of ActionMCP is meant to connect to remote MCP servers only. Connecting to local processes (such as via STDIO) is not supported.

## Installation

To start using ActionMCP, add it to your project:

- **Using Bundler (Rails or Ruby projects):** Add the gem to your Gemfile and run bundle install:

  ```bash
  $ bundle add actionmcp
  ```

After adding the gem, run the install generator to set up the basic ActionMCP structure:

```bash
bundle install
bin/rails action_mcp:install:migrations
bin/rails db:migrate
bin/rails generate action_mcp:install
```

This will create the base application classes, configuration file, and necessary database tables for ActionMCP to function properly.

## Core Components

ActionMCP provides three core abstractions to streamline MCP server development:

### ActionMCP::Prompt

`ActionMCP::Prompt` enables you to create reusable prompt templates that can be discovered and used by LLMs. Each prompt is defined as a Ruby class that inherits from `ApplicationMCPPrompt`.

Key features:
- Define expected arguments with descriptions and validation rules
- Build multi-step conversations with mixed content types
- Support for text, images, audio, and resource attachments
- Add messages with different roles (user/assistant)

**Example:**

```ruby
class AnalyzeCodePrompt < ApplicationMCPPrompt
  prompt_name "analyze_code"
  description "Analyze code for potential improvements"

  argument :language, description: "Programming language", default: "Ruby"
  argument :code, description: "Code to explain", required: true

  validates :language, inclusion: { in: %w[Ruby Python JavaScript] }

  def perform
    render(text: "Please analyze this #{language} code for improvements:")
    render(text: code)
    
    # You can add assistant messages too
    render(text: "Here are some things to focus on in your analysis:", role: :assistant)
    
    # Even add resources if needed
    render(resource: "file://documentation/#{language.downcase}_style_guide.pdf", 
           mime_type: "application/pdf", 
           blob: get_style_guide_pdf(language))
  end
  
  private
  
  def get_style_guide_pdf(language)
    # Implementation to retrieve style guide as base64
  end
end
```

Prompts can be executed by instantiating them and calling the `call` method:

```ruby
analyze_prompt = AnalyzeCodePrompt.new(language: "Ruby", code: "def hello; puts 'Hello, world!'; end")
result = analyze_prompt.call
```

### ActionMCP::Tool

`ActionMCP::Tool` allows you to create interactive functions that LLMs can call with arguments to perform specific tasks. Each tool is a Ruby class that inherits from `ApplicationMCPTool`.

Key features:
- Define input properties with types, descriptions, and validation
- Return multiple response types (text, images, errors)
- Progressive responses with multiple render calls
- Automatic input validation based on property definitions

**Example:**

```ruby
class CalculateSumTool < ApplicationMCPTool
  tool_name "calculate_sum"
  description "Calculate the sum of two numbers"

  property :a, type: "number", description: "First number", required: true
  property :b, type: "number", description: "Second number", required: true
  
  def perform
    sum = a + b
    render(text: "Calculating #{a} + #{b}...")
    render(text: "The sum is #{sum}")
    
    # You can render errors if needed
    if sum > 1000
      render(error: ["Warning: Sum exceeds recommended limit"])
    end
    
    # Or even images
    render(image: generate_visualization(a, b), mime_type: "image/png")
  end
  
  private
  
  def generate_visualization(a, b)
    # Implementation to create a visualization as base64
  end
end
```

Tools can be executed by instantiating them and calling the `call` method:

```ruby
sum_tool = CalculateSumTool.new(a: 5, b: 10)
result = sum_tool.call
```

### ActionMCP::ResourceTemplate

`ActionMCP::ResourceTemplate` facilitates the creation of URI templates for dynamic resources that LLMs can access. 
This allows models to request specific data using parameterized URIs.

**Example:**

```ruby

class ProductResourceTemplate < ApplicationMCPResTemplate
  uri_template "product/{id}"
  description "Access product information by ID"

  parameter :id, description: "Product identifier", required: true

  validates :id, format: { with: /\A\d+\z/, message: "must be numeric" }

  def resolve
    product = Product.find_by(id: id)
    return unless product
    ActionMCP::Resource.new(
      uri: "ecommerce://products/#{product_id}",
      name: "Product #{product_id}",
      description: "Product information for product #{product_id}",
      mime_type: "application/json",
      size: product.to_json.length
    )
  end
end
```

# Example of callbacks:

```ruby
before_resolve do |template|
  logger.tagged("ProductsTemplate") { logger.info("Starting to resolve product: #{template.product_id}") }
end

after_resolve do |template|
  logger.tagged("ProductsTemplate") { logger.info("Finished resolving product resource for product: #{template.product_id}") }
end

around_resolve do |template, block|
  start_time = Time.current
  logger.tagged("ProductsTemplate") { logger.info("Starting resolution for product: #{template.product_id}") }

  resource = block.call

  if resource
    logger.tagged("ProductsTemplate") { logger.info("Product #{template.product_id} resolved successfully in #{Time.current - start_time}s") }
  else
    logger.tagged("ProductsTemplate") { logger.info("Product #{template.product_id} not found") }
  end

  resource
end
```

Resource templates are automatically registered and used when LLMs request resources matching their patterns.

## Configuration

ActionMCP is configured via `config.action_mcp` in your Rails application.

By default, the name is set to your application's name and the version defaults to "0.0.1" unless your app has a version file.

You can override these settings in your configuration (e.g., in `config/application.rb`):

```ruby
module Tron
  class Application < Rails::Application
    config.action_mcp.name = "Friendly MCP (Master Control Program)"  # defaults to Rails.application.name
    config.action_mcp.version = "1.2.3"                               # defaults to "0.0.1"
    config.action_mcp.logging_enabled = true                          # defaults to true
    config.action_mcp.logging_level = :info                           # defaults to :info, can be :debug, :info, :warn, :error, :fatal
    config.action_mcp.vibed_ignore_version = false                    # defaults to false, set to true to ignore client protocol version mismatches
  end
end
```

For dynamic versioning, consider adding the `rails_app_version` gem.

### Protocol Version Compatibility

By default, ActionMCP requires clients to use the exact protocol version supported by the server (currently "2025-03-26"). If the client specifies a different version during initialization, the request will be rejected with an error.

To support clients with incompatible protocol versions, you can enable the `vibed_ignore_version` option:

```ruby
# In config/application.rb or an initializer
Rails.application.config.action_mcp.vibed_ignore_version = true
```

When enabled, the server will ignore protocol version mismatches from clients and always use the latest supported version. This is useful for:
- Development environments with older client libraries
- Supporting clients that cannot be easily updated
- Situations where protocol differences are minor and known to be compatible

> **Note:** Using `vibed_ignore_version = true` in production is not recommended as it may lead to unexpected behavior if clients rely on specific protocol features that differ between versions.

### PubSub Configuration

ActionMCP uses a pub/sub system for real-time communication. You can choose between several adapters:

1. **SolidCable** - Database-backed pub/sub (no Redis required)
2. **Simple** - In-memory pub/sub for development and testing
3. **Redis** - Redis-backed pub/sub (if you prefer Redis)

#### Migrating from ActionCable

If you were previously using ActionCable with ActionMCP, you will need to migrate to the new PubSub system. Here's how:

1. Remove the ActionCable dependency from your Gemfile (if you don't need it for other purposes)
2. Install one of the PubSub adapters (SolidCable recommended)
3. Create a configuration file at `config/mcp.yml` (you can use the generator: `bin/rails g action_mcp:config`)
4. Run your tests to ensure everything works correctly

The new PubSub system maintains the same API as the previous ActionCable-based implementation, so your existing code should continue to work without changes.

Configure your adapter in `config/mcp.yml`:

```yaml
development:
  adapter: solid_cable
  polling_interval: 0.1.seconds
  # Thread pool configuration (optional)
  # min_threads: 5     # Minimum number of threads in the pool
  # max_threads: 10    # Maximum number of threads in the pool
  # max_queue: 100     # Maximum number of tasks that can be queued

test:
  adapter: test    # Uses the simple in-memory adapter

production:
  adapter: solid_cable
  polling_interval: 0.5.seconds
  # Optional: connects_to: cable  # If using a separate database
  
  # Thread pool configuration for high-traffic environments
  min_threads: 10     # Minimum number of threads in the pool
  max_threads: 20     # Maximum number of threads in the pool
  max_queue: 500      # Maximum number of tasks that can be queued
```

#### SolidMCP (Database-backed, Recommended)

For SolidMCP, add it to your Gemfile:

```ruby
gem "solid_mcp"  # Database-backed adapter optimized for MCP
```

Then install it:

```bash
bundle install
bin/rails solid_mcp:install:migrations
bin/rails db:migrate
```

The installer will create the necessary database migration for message storage. Configure it in your `config/mcp.yml`.

#### Redis Adapter

If you prefer Redis, add it to your Gemfile:

```ruby
gem "redis", "~> 5.0"
```

Then configure the Redis adapter in your `config/mcp.yml`:

```yaml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: your_app_production
  
  # Thread pool configuration for high-traffic environments
  min_threads: 10     # Minimum number of threads in the pool
  max_threads: 20     # Maximum number of threads in the pool
  max_queue: 500      # Maximum number of tasks that can be queued
```

## Session Storage

ActionMCP provides a pluggable session storage system that allows you to choose how sessions are persisted based on your environment and requirements.

### Session Store Types

ActionMCP includes three session store implementations:

1. **`:volatile`** - In-memory storage using Concurrent::Hash
   - Default for development and test environments
   - Sessions are lost on server restart
   - Fast and lightweight for local development
   - No external dependencies

2. **`:active_record`** - Database-backed storage
   - Default for production environment
   - Sessions persist across server restarts
   - Supports session resumability
   - Requires database migrations

3. **`:test`** - Special store for testing
   - Tracks notifications and method calls
   - Provides assertion helpers
   - Automatically used in test environment when using TestHelper

### Configuration

You can configure the session store type in your Rails configuration or `config/mcp.yml`:

```ruby
# config/application.rb or environment files
Rails.application.configure do
  config.action_mcp.session_store_type = :active_record  # or :volatile
end
```

Or in `config/mcp.yml`:

```yaml
# Global session store type (used by both client and server)
session_store_type: volatile

# Client-specific session store type (falls back to session_store_type if not specified)
client_session_store_type: volatile

# Server-specific session store type (falls back to session_store_type if not specified)  
server_session_store_type: active_record
```

The defaults are:
- Production: `:active_record`
- Development: `:volatile`
- Test: `:volatile` (or `:test` when using TestHelper)

### Separate Client and Server Session Stores

You can configure different session store types for client and server operations:

- **`session_store_type`**: Global setting used by both client and server when specific types aren't set
- **`client_session_store_type`**: Session store used by ActionMCP client connections (falls back to global setting)
- **`server_session_store_type`**: Session store used by ActionMCP server sessions (falls back to global setting)

This allows you to optimize each component separately. For example, you might use volatile storage for client sessions (faster, temporary) while using persistent storage for server sessions (maintains state across restarts).

### Using Different Session Stores

```ruby
# The session store is automatically selected based on configuration
# You can access it directly if needed:
session_store = ActionMCP::Server.session_store

# Create a session
session = session_store.create_session(session_id, {
  status: "initialized",
  protocol_version: "2025-03-26",
  # ... other session attributes
})

# Load a session
session = session_store.load_session(session_id)

# Update a session
session_store.update_session(session_id, { status: "active" })

# Delete a session
session_store.delete_session(session_id)
```

### Session Resumability

With the `:active_record` store, clients can resume sessions after disconnection:

```ruby
# Client includes session ID in request headers
# Server automatically resumes the existing session
headers["Mcp-Session-Id"] = "existing-session-id"

# If the session exists, it will be resumed
# If not, a new session will be created
```

### Custom Session Stores

You can create custom session stores by inheriting from `ActionMCP::Server::SessionStore::Base`:

```ruby
class MyCustomSessionStore < ActionMCP::Server::SessionStore::Base
  def create_session(session_id, payload = {})
    # Implementation
  end

  def load_session(session_id)
    # Implementation
  end

  def update_session(session_id, updates)
    # Implementation
  end

  def delete_session(session_id)
    # Implementation
  end

  def exists?(session_id)
    # Implementation
  end
end

# Register your custom store
ActionMCP::Server.session_store = MyCustomSessionStore.new
```

## Thread Pool Management

ActionMCP uses thread pools to efficiently handle message callbacks. This prevents the system from being overwhelmed by too many threads under high load.

### Thread Pool Configuration

You can configure the thread pool in your `config/mcp.yml`:

```yaml
production:
  adapter: solid_cable
  # Thread pool configuration
  min_threads: 10    # Minimum number of threads to keep in the pool
  max_threads: 20    # Maximum number of threads the pool can grow to
  max_queue: 500     # Maximum number of tasks that can be queued
```

The thread pool will automatically:
- Start with `min_threads` threads
- Scale up to `max_threads` as needed
- Queue tasks up to `max_queue` limit
- Use caller's thread if queue is full (fallback policy)

### Graceful Shutdown

When your application is shutting down, you should call:

```ruby
ActionMCP::Server.shutdown
```

This ensures all thread pools are properly terminated and tasks are completed.

## Engine and Mounting

**ActionMCP** runs as a standalone Rack application. **Do not attempt to mount it in your application's `routes.rb`**—it is not designed to be mounted as an engine at a custom path. When you use `run ActionMCP::Engine` in your `mcp.ru`, the MCP endpoint is always available at the root path (`/`).

### Installing ActionMCP

ActionMCP includes generators to help you set up your project quickly. The install generator creates all necessary base classes and configuration files:

```bash
# Install ActionMCP with base classes and configuration
bin/rails generate action_mcp:install
```

This will create:
- `app/mcp/prompts/application_mcp_prompt.rb` - Base prompt class
- `app/mcp/tools/application_mcp_tool.rb` - Base tool class  
- `app/mcp/resource_templates/application_mcp_res_template.rb` - Base resource template class
- `app/mcp/application_gateway.rb` - Gateway for authentication
- `config/mcp.yml` - Configuration file with example settings for all environments

> **Note:** Authentication and authorization are not included. You are responsible for securing the endpoint.

## Authentication with Gateway

ActionMCP provides a Gateway system similar to ActionCable's Connection for handling authentication. The Gateway allows you to authenticate users and make them available throughout your MCP components.

ActionMCP supports multiple authentication methods including OAuth 2.1, JWT tokens, and no authentication for development. For detailed OAuth 2.1 configuration and usage, see the [OAuth Authentication Guide](OAUTH.md).

### Creating an ApplicationGateway

When you run the install generator, it creates an `ApplicationGateway` class:

```ruby
# app/mcp/application_gateway.rb
class ApplicationGateway < ActionMCP::Gateway
  # Specify what attributes identify a connection
  identified_by :user

  protected

  def authenticate!
    token = extract_bearer_token
    raise ActionMCP::UnauthorizedError, "Missing token" unless token

    payload = ActionMCP::JwtDecoder.decode(token)
    user = resolve_user(payload)
    
    raise ActionMCP::UnauthorizedError, "Unauthorized" unless user

    # Return a hash with all identified_by attributes
    { user: user }
  end

  private

  def resolve_user(payload)
    user_id = payload["user_id"] || payload["sub"]
    User.find_by(id: user_id) if user_id
  end
end
```

### Using Multiple Identifiers

You can identify connections by multiple attributes:

```ruby
class ApplicationGateway < ActionMCP::Gateway
  identified_by :user, :organization
  
  protected
  
  def authenticate!
    # ... authentication logic ...
    
    { 
      user: user,
      organization: user.organization
    }
  end
end
```

### Accessing Current User in Components

Once authenticated, the current user (and other identifiers) are available in your tools, prompts, and resource templates:

```ruby
class MyTool < ApplicationMCPTool
  def perform
    # Access the authenticated user
    if current_user
      render text: "Hello, #{current_user.name}!"
    else
      render text: "Hi Stranger! It's been a while "
    end
  end
end
```

### Current Attributes

ActionMCP uses Rails' CurrentAttributes to store the authenticated context. The `ActionMCP::Current` class provides:
- `ActionMCP::Current.user` - The authenticated user
- `ActionMCP::Current.gateway` - The gateway instance
- Any other attributes you define with `identified_by`

### 1. Create `mcp.ru`

```ruby
# Load the full Rails environment to access models, DB, Redis, etc.
require_relative "config/environment"

# No need to set a custom endpoint path. The MCP endpoint is always served at root ("/")
# when using ActionMCP::Engine directly.
run ActionMCP::Engine
```
### 2. Start the server
```bash
bin/rails s -c mcp.ru -p 62770 -P tmp/pids/mcps0.pid
```

### Dealing with Middleware Conflicts

If your Rails application uses middleware that interferes with MCP server operation (like Devise, Warden, Ahoy, Rack::Cors, etc.), use `mcp_vanilla.ru` instead:

```ruby
# mcp_vanilla.ru - A minimal Rack app with only essential middleware
# This avoids conflicts with authentication, tracking, and other web-specific middleware
# See the file for detailed documentation on when and why to use it

bundle exec rails s -c mcp_vanilla.ru -p 62770
# Or with Falcon:
bundle exec falcon serve --bind http://0.0.0.0:62770 --config mcp_vanilla.ru
```

Common middleware that can cause issues:
- **Devise/Warden** - Expects cookies and sessions, throws `Devise::MissingWarden` errors
- **Ahoy** - Analytics tracking that intercepts requests
- **Rack::Attack** - Rate limiting designed for web traffic
- **Rack::Cors** - CORS headers meant for browsers
- Any middleware assuming HTML responses or cookie-based authentication

An example of a minimal `mcp_vanilla.ru` file is located in the dummy app : test/dummy/mcp_vanilla.ru. 
This file is a minimal Rack application that only includes the essential middleware needed for MCP server operation, avoiding conflicts with web-specific middleware.
But remember to add any instrumentation or logging middleware you need, as the minimal setup will not include them by default.

```ruby

## Production Deployment of MCPS0

In production, **MCPS0** (the MCP server) is a standard Rack application. You can run it using any Rack-compatible server (such as Puma, Unicorn, or Passenger). 

> **For best performance and concurrency, it is highly recommended to use a modern, synchronous server like [Falcon](https://github.com/socketry/falcon)**. Falcon is optimized for streaming and concurrent workloads, making it ideal for MCP servers. You can still use Puma, Unicorn, or Passenger, but Falcon will generally provide superior throughput and responsiveness for real-time and streaming use cases.

You have two main options for exposing the server:

### 1. Dedicated Port

Run MCPS0 on its own TCP port (commonly `62770`):

**With Falcon:**
```bash
bundle exec falcon serve --bind http://0.0.0.0:62770 --config mcp.ru
```

**With Puma:**
```bash
bundle exec rails s -c mcp.ru -p 62770
```

Then, use your web server (Nginx, Apache, etc.) to reverse proxy requests to this port.

### 2. Unix Socket

Alternatively, you can run MCPS0 on a Unix socket for improved performance and security (especially when the web server and app server are on the same machine):

**With Falcon:**
```bash
bundle exec falcon serve --bind unix:/tmp/mcps0.sock mcp.ru
```

**With Puma:**
```bash
bundle exec puma -C config/puma.rb -b unix:///tmp/mcps0.sock -c mcp.ru
```

And configure your web server to proxy to the socket:

```nginx
location /mcp/ {
  proxy_pass http://unix:/tmp/mcps0.sock:;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

**Key Points:**
- MCPS0 is a standalone Rack app—run it separately from your main Rails server.
- You can expose it via a TCP port (e.g., 62770) or a Unix socket.
- Use a reverse proxy (Nginx, Apache, etc.) to route requests to MCPS0 as needed.
- This separation ensures reliability and scalability for both your main app and MCP services.

## Generators

ActionMCP includes Rails generators to help you quickly set up your MCP server components.

First, install ActionMCP to create base classes and configuration:

```bash
bin/rails action_mcp:install:migrations  # to copy the migrations
bin/rails generate action_mcp:install 
```

This will create the base application classes, configuration file, and authentication gateway in your app directory.

### Generate a New Prompt

```bash
bin/rails generate action_mcp:prompt AnalyzeCode
```

### Generate a New Tool

```bash
bin/rails generate action_mcp:tool CalculateSum
```

## Testing with TestHelper

ActionMCP provides a `TestHelper` module to simplify testing of tools and prompts:

```ruby
require "test_helper"
require "action_mcp/test_helper"

class ToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "CalculateSumTool returns the correct sum" do
    assert_tool_findable("calculate_sum")
    result = execute_tool("calculate_sum", a: 5, b: 10)
    assert_tool_output(result, "15.0")
  end

  test "AnalyzeCodePrompt returns the correct analysis" do
    assert_prompt_findable("analyze_code")
    result = execute_prompt("analyze_code", language: "Ruby", code: "def hello; puts 'Hello, world!'; end")
    assert_equal "Analyzing Ruby code: def hello; puts 'Hello, world!'; end", assert_prompt_output(result)
  end
end
```

## Inspecting Your MCP Server

You can use the MCP Inspector to test your server implementation:

```bash
npx @modelcontextprotocol/inspector
```

The default path will be http://localhost:3000/action_mcp

Here's a section you can add to explain the profile system in ActionMCP:

## Profiles

ActionMCP supports a flexible profile system that allows you to selectively expose tools, prompts, and resources based on different usage scenarios. This is particularly useful for applications that need different MCP capabilities for different contexts (e.g., public API vs. admin interface).

### Understanding Profiles

Profiles are named configurations that define:

- Which tools are available
- Which prompts are accessible
- Which resources can be accessed
- Configuration options like logging level and change notifications

By default, ActionMCP includes two profiles:
- `primary`: Exposes all tools, prompts, and resources
- `minimal`: Exposes no tools, prompts, or resources by default

### Configuring Profiles

Profiles are configured via a `config/mcp.yml` file in your Rails application. If this file doesn't exist, ActionMCP will use default settings from the gem.

**Example configuration:**

```yaml
default:
  tools:
    - all  # Include all tools
  prompts:
    - all  # Include all prompts
  resources:
    - all  # Include all resources
  options:
    list_changed: false
    logging_enabled: true
    logging_level: info
    resources_subscribe: false

api_only:
  tools:
    - calculator
    - weather
  prompts: []  # No prompts for API
  resources:
    - user_profile
  options:
    list_changed: false
    logging_level: warn

admin:
  tools:
    - all
  options:
    logging_level: debug
    list_changed: true
    resources_subscribe: true
```

Each profile can specify:
- `tools`: Array of tool names to include (use `all` to include all tools)
- `prompts`: Array of prompt names to include (use `all` to include all prompts)
- `resources`: Array of resource names to include (use `all` to include all resources)
- `options`: Additional configuration options:
  - `list_changed`: Whether to send change notifications
  - `logging_enabled`: Whether to enable logging
  - `logging_level`: The logging level to use
  - `resources_subscribe`: Whether to enable resource subscriptions

### Switching Profiles

You can switch between profiles programmatically in your code:

```ruby
# Permanently switch to a different profile
ActionMCP.configuration.use_profile(:only_tools)  # Switch to a profile named "only_tools"

# Temporarily use a profile for a specific operation
ActionMCP.with_profile(:minimal) do
  # Code here uses the minimal profile
  # After the block, reverts to the previous profile
end
```

This makes it easy to control which MCP capabilities are available in different contexts of your application.

### Inspecting Profiles

ActionMCP includes rake tasks to help you manage and inspect your profiles:

```bash
# List all available profiles with their configurations
bin/rails action_mcp:list_profiles

# Show detailed information about a specific profile
bin/rails action_mcp:show_profile[admin]

# List all tools, prompts, resources, and profiles
bin/rails action_mcp:list
```

The profile inspection tasks will highlight any issues, such as configured tools, prompts, or resources that don't actually exist in your application.

### Use Cases

Profiles are particularly useful for:

1. **Multi-tenant applications**: Use different profiles for different customer tiers with Dorp or other gems
2. **Access control**: Create profiles for different user roles (admin, staff, public)
3. **Performance optimization**: Use a minimal profile for high-traffic endpoints
4. **Testing environments**: Use specific test profiles in your test environment
5. **Progressive enhancement**: Start with a minimal profile and gradually add capabilities

By leveraging profiles, you can maintain a single ActionMCP codebase while providing tailored MCP capabilities for different contexts.

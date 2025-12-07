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

ActionMCP supports **MCP 2025-06-18** (current) with backward compatibility for **MCP 2025-03-26**. The protocol implementation is fully compliant with the MCP specification, including:

- **JSON-RPC 2.0** transport layer
- **Capability negotiation** during initialization
- **Error handling** with proper error codes (-32601 for method not found, -32002 for consent required)
- **Session management** with resumable sessions
- **Change notifications** for dynamic capability updates

For a detailed (and entertaining) breakdown of protocol versions, features, and our design decisions, see [The Hitchhiker's Guide to MCP](The_Hitchhikers_Guide_to_MCP.md).

*Don't Panic: The guide contains everything you need to know about surviving MCP protocol versions.*

> **Note:** STDIO transport is not supported in ActionMCP. This gem is focused on production-ready, network-based deployments. STDIO is only suitable for desktop or script-based experimentation and is intentionally excluded.

Instead of implementing MCP support from scratch, you can subclass and configure the provided **Prompt**, **Tool**, and **ResourceTemplate** classes to expose your app's functionality to LLMs.

ActionMCP handles the underlying MCP message format and routing, so you can adhere to the open standard with minimal effort.

In short, ActionMCP helps you build an MCP server (the component that exposes capabilities to AI) more quickly and with fewer mistakes.

> **Client connections:** The client part of ActionMCP is meant to connect to remote MCP servers only. Connecting to local processes (such as via STDIO) is not supported.

## Installation

To start using ActionMCP, add it to your project:

```bash
# Add gem to your Gemfile
$ bundle add actionmcp

# Install dependencies
bundle install

# Copy migrations from the engine
bin/rails action_mcp:install:migrations

# Generate base classes and configuration
bin/rails generate action_mcp:install

# Create necessary database tables
bin/rails db:migrate
```

The `action_mcp:install` generator will:
- Create base application classes (ApplicationGateway, ApplicationMCPTool, etc.)
- Generate the MCP configuration file (`config/mcp.yml`)
- Set up the basic directory structure for MCP components (`app/mcp/`)

Database migrations are copied separately using `bin/rails action_mcp:install:migrations`.

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
- **Consent management for sensitive operations**

**Example:**

```ruby
class CalculateSumTool < ApplicationMCPTool
  tool_name "calculate_sum"
  description "Calculate the sum of two numbers"

  property :a, type: "number", description: "The first number", required: true
  property :b, type: "number", description: "The second number", required: true

  def perform
    sum = a + b
    render(text: "Calculating #{a} + #{b}...")
    render(text: "The sum is #{sum}")

    # You can report errors if needed
    if sum > 1000
      report_error("Warning: Sum exceeds recommended limit")
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

#### Consent Management

For tools that perform sensitive operations (file system access, database modifications, external API calls), you can require explicit user consent:

```ruby
class FileSystemTool < ApplicationMCPTool
  tool_name "read_file"
  description "Read contents of a file"
  
  # Require explicit consent before execution
  requires_consent!

  property :file_path, type: "string", description: "Path to file", required: true

  def perform
    # This code only runs after user grants consent
    content = File.read(file_path)
    render(text: "File contents: #{content}")
  end
end
```

**Consent Flow:**
1. When a consent-required tool is called without consent, it returns a JSON-RPC error with code `-32002`
2. The client must explicitly grant consent for the specific tool
3. Once granted, the tool can execute normally for that session
4. Consent is session-scoped and can be revoked at any time

**Managing Consent:**

```ruby
# Check if consent is granted
session.consent_granted_for?("read_file")

# Grant consent for a tool
session.grant_consent("read_file")

# Revoke consent
session.revoke_consent("read_file")
```

Tools can be executed by instantiating them and calling the `call` method:

```ruby
sum_tool = CalculateSumTool.new(a: 5, b: 10)
result = sum_tool.call
```

#### Structured output (output_schema)

Advertise a JSON Schema for your tool's structuredContent and return machine-validated results alongside any text output.

```ruby
class PriceQuoteTool < ApplicationMCPTool
  tool_name "price_quote"
  description "Return a structured price quote"

  property :sku, type: "string", description: "SKU to price", required: true

  output_schema do
    string :sku, required: true, description: "SKU that was priced"
    number :price_cents, required: true, description: "Total price in cents"
    object :meta do
      string :currency, required: true, enum: %w[USD EUR GBP]
      boolean :cached, default: false
    end
  end

  def perform
    price_cents = lookup_price_cents(sku) # Implement your lookup

    render structured: { sku: sku,
                         price_cents: price_cents,
                         meta: { currency: "USD", cached: false } }
  end
end
```

The schema is included in the tool definition, and the `structured` payload is emitted as `structuredContent` in the response while remaining compatible with text/audio/image renders.

#### Returning resource links from a tool

When you want to hand back a URI instead of embedding the payload, use the built-in `render_resource_link`, which produces the MCP `resource_link` content type.

```ruby
class ReportLinkTool < ApplicationMCPTool
  tool_name "report_link"
  description "Return a downloadable report link"

  property :report_id, type: "string", required: true

  def perform
    render_resource_link(
      uri: "reports://#{report_id}.json",
      name: "Report #{report_id}",
      description: "Downloadable JSON for report #{report_id}",
      mime_type: "application/json"
    )
  end
end
```

Clients can resolve the URI with a separate `resources/read` call, keeping tool responses lightweight while still discoverable.

#### Task-augmented tools (async execution with progress)

Use MCP Tasks when work might take seconds/minutes. Advertise task support with `task_required!` (or `task_optional!`) and let callers opt in by sending `_meta.task` on `tools/call`. While running as a task, you can emit progress updates with `report_progress!`.

```ruby
class BatchIndexTool < ApplicationMCPTool
  tool_name "batch_index"
  description "Index many items asynchronously with progress updates"

  task_required! # advertise that this tool is intended to run as a task
  property :items, type: "array_string", description: "Items to index", required: true

  def perform
    total = items.length
    items.each_with_index do |item, idx|
      index_item(item) # your indexing logic

      percent = ((idx + 1) * 100.0 / total).round
      report_progress!(percent: percent, message: "Indexed #{idx + 1}/#{total}")
    end

    render(text: "Indexed #{total} items")
  end

  private

  def index_item(item)
    # Implement your indexing logic here
  end
end
```

Call it as a task from a client by adding `_meta.task` (creates a Task record and runs the tool via `ToolExecutionJob`):

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "batch_index",
    "arguments": { "items": ["a", "b", "c"] },
    "_meta": { "task": { "ttl": 120000, "pollInterval": 2000 } }
  }
}
```

Poll task status with `tasks/get` or fetch the result when finished with `tasks/result`. Use `tasks/cancel` to stop non-terminal tasks.

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
  # Starting to resolve product: #{template.product_id}
end

after_resolve do |template|
  # Finished resolving product resource for product: #{template.product_id}
end

around_resolve do |template, block|
  start_time = Time.current
  # Starting resolution for product: #{template.product_id}

  resource = block.call

  if resource
    # Product #{template.product_id} resolved successfully in #{Time.current - start_time}s
  else
    # Product #{template.product_id} not found
  end

  resource
end
```

Resource templates are automatically registered and used when LLMs request resources matching their patterns.

## 📚 Documentation

ActionMCP provides comprehensive documentation across multiple specialized guides. Each guide focuses on specific aspects to keep information organized and prevent context overload:

### Getting Started & Setup
- **[Installation & Configuration](README.md#installation)** - Initial setup, database migrations, and basic configuration
- **[Authentication with Gateway](README.md#authentication-with-gateway)** - User authentication and authorization patterns

### Component Development  
- **[📋 TOOLS.MD](TOOLS.MD)** - Complete guide to developing MCP tools
  - Generator usage and best practices
  - Property definitions, validation, and consent management
  - Output schemas for structured responses
  - Error handling, testing, and security considerations
  - Advanced features like additional properties and authentication context

- **[📝 PROMPTS.MD](PROMPTS.MD)** - Prompt template development guide
  - Creating reusable prompt templates
  - Multi-step conversations and mixed content types
  - Argument validation and prompt chaining

- **[🔗 RESOURCE_TEMPLATES.md](RESOURCE_TEMPLATES.md)** - Resource template implementation
  - URI template patterns and parameter extraction
  - Dynamic resource resolution and collections
  - Callbacks and validation patterns

### Client & Integration
- **[🔌 CLIENTUSAGE.MD](CLIENTUSAGE.MD)** - Complete client implementation guide
  - Session management and resumability
  - Transport configuration and connection handling
  - Tool, prompt, and resource collections
  - Production deployment patterns
- **[🔐 GATEWAY.md](GATEWAY.md)** - Authentication gateway guide
  - Implementing `ApplicationGateway`
  - Identifier handling via `ActionMCP::Current`
  - Auth patterns, error handling, and hardening tips

### Protocol & Technical Details
- **[🚀 The Hitchhiker's Guide to MCP](The_Hitchhikers_Guide_to_MCP.md)** - Protocol versions and migration
  - Comprehensive comparison of MCP protocol versions (2024-11-05, 2025-03-26, 2025-06-18)
  - Design decisions and architectural rationale
  - Migration paths and compatibility considerations
  - Feature evolution and technical specifications (*Don't Panic!*)

### Advanced Configuration
- **[Session Storage](README.md#session-storage)** - Volatile vs ActiveRecord vs custom session stores
- **[Thread Pool Management](README.md#thread-pool-management)** - Performance tuning and graceful shutdown
- **[Profiles System](README.md#profiles)** - Multi-tenant capability filtering
- **[Production Deployment](README.md#production-deployment-of-mcps0)** - Falcon, Unix sockets, and reverse proxy setup

### Development & Testing
- **[Generators](README.md#generators)** - Rails generators for scaffolding components
- **[Testing with TestHelper](README.md#testing-with-testhelper)** - Comprehensive testing strategies
- **[Development Commands](README.md#development-commands)** - Rake tasks for debugging and inspection
- **[MCP Inspector Integration](README.md#inspecting-your-mcp-server)** - Interactive testing and validation

### Troubleshooting & Production
- **[Error Handling](README.md#error-handling-and-troubleshooting)** - JSON-RPC error codes and debugging
- **[Production Considerations](README.md#production-considerations)** - Security, performance, and monitoring
- **[Middleware Conflicts](README.md#dealing-with-middleware-conflicts)** - Using `mcp_vanilla.ru` for production

> **💡 Pro Tip**: Start with the component-specific guides (TOOLS.MD, PROMPTS.MD, RESOURCE_TEMPLATES.md) for hands-on development, then reference the Hitchhiker's Guide for protocol details and CLIENTUSAGE.MD for integration patterns.

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
  end
end
```

For dynamic versioning, consider adding the `rails_app_version` gem.


### PubSub Configuration

ActionMCP uses a pub/sub system for real-time communication. You can choose between several adapters:

1. **SolidMCP** - Database-backed pub/sub (no Redis required)
2. **Simple** - In-memory pub/sub for development and testing
3. **Redis** - Redis-backed pub/sub (if you prefer Redis)

#### Migrating from ActionCable

If you were previously using ActionCable with ActionMCP, you will need to migrate to the new PubSub system. Here's how:

1. Remove the ActionCable dependency from your Gemfile (if you don't need it for other purposes)
2. Install one of the PubSub adapters (SolidMCP recommended)
3. Create a configuration file at `config/mcp.yml` (you can use the generator: `bin/rails g action_mcp:config`)
4. Run your tests to ensure everything works correctly

The new PubSub system maintains the same API as the previous ActionCable-based implementation, so your existing code should continue to work without changes.

Configure your adapter in `config/mcp.yml`:

```yaml
development:
  adapter: solid_mcp
  polling_interval: 0.1.seconds
  # Thread pool configuration (optional)
  # min_threads: 5     # Minimum number of threads in the pool
  # max_threads: 10    # Maximum number of threads in the pool
  # max_queue: 100     # Maximum number of tasks that can be queued

test:
  adapter: test    # Uses the simple in-memory adapter

production:
  adapter: solid_mcp
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
  adapter: solid_mcp
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

ActionMCP uses a Gateway pattern with pluggable identifiers for authentication. You can implement custom authentication strategies using session-based auth, API keys, bearer tokens, or integrate with existing authentication systems like Warden, Devise, or external OAuth providers.

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

The TestHelper provides several assertion methods:
- `assert_tool_findable(name)` - Verifies a tool exists and is registered
- `assert_prompt_findable(name)` - Verifies a prompt exists and is registered
- `execute_tool(name, **args)` - Executes a tool with arguments
- `execute_prompt(name, **args)` - Executes a prompt with arguments
- `assert_tool_output(result, expected)` - Asserts tool output matches expected text
- `assert_prompt_output(result)` - Extracts and returns prompt output for assertions

## Inspecting Your MCP Server

You can use the MCP Inspector to test your server implementation:

```bash
# Start your MCP server
bundle exec rails s -c mcp.ru -p 62770

# In another terminal, run the inspector
npx @modelcontextprotocol/inspector --url http://localhost:62770
```

The MCP Inspector provides an interactive interface to:
- Test tool executions with custom arguments
- Validate prompt responses
- Inspect resource templates and their outputs
- Debug protocol compliance and error handling

## Development Commands

ActionMCP includes several rake tasks for development and debugging:

```bash
# List all MCP components
bundle exec rails action_mcp:list

# List specific component types
bundle exec rails action_mcp:list_tools
bundle exec rails action_mcp:list_prompts
bundle exec rails action_mcp:list_resources
bundle exec rails action_mcp:list_profiles

# Show configuration and statistics
bundle exec rails action_mcp:info
bundle exec rails action_mcp:stats

# Show profile configuration
bundle exec rails action_mcp:show_profile[profile_name]
```

## Error Handling and Troubleshooting

ActionMCP provides comprehensive error handling following the JSON-RPC 2.0 specification:

### Error Codes

- **-32601**: Method not found - The requested method doesn't exist
- **-32002**: Consent required - Tool requires user consent to execute
- **-32603**: Internal error - Server encountered an unexpected error
- **-32600**: Invalid request - The request is malformed

### Context-Aware Error Messages

Tools should return clear error messages to the LLM using the `render` method:

```ruby
class MyTool < ApplicationMCPTool
  def perform
    # Check for error conditions and return clear messages
    if some_error_condition?
      report_error("Clear error message for the LLM")
      return
    end
    
    # Normal processing
    render(text: "Success message")
  end
end
```

### Common Issues

1. **Session not found**: Ensure sessions are properly created and saved in the session store
2. **Tool not registered**: Verify tools are properly defined and inherit from ApplicationMCPTool
3. **Consent required**: Grant consent using `session.grant_consent(tool_name)`
4. **Middleware conflicts**: Use `mcp_vanilla.ru` to avoid web-specific middleware

### Debugging Tips

- Check server logs for detailed error information
- Use `bundle exec rails action_mcp:info` to verify configuration
- Test with MCP Inspector to isolate protocol issues
- Ensure proper session management in production environments

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

## Client Usage

ActionMCP includes a client for connecting to remote MCP servers. The client handles session management, protocol negotiation, and provides a simple API for interacting with MCP servers.

For comprehensive client documentation, including examples, session management, transport configuration, and API usage, see [CLIENTUSAGE.md](CLIENTUSAGE.md).

## Production Considerations

### Security

- **Never expose sensitive data** through MCP components
- **Use authentication** via Gateway for production deployments
- **Implement proper authorization** in your tools and prompts
- **Validate all inputs** using property definitions and Rails validations
- **Use consent management** for sensitive operations

### Performance

- **Configure appropriate thread pools** for high-traffic scenarios
- **Use Redis or SolidMCP** for production pub/sub
- **Choose ActiveRecord session store** for session persistence
- **Monitor session cleanup** to prevent memory leaks
- **Use profiles** to limit exposed capabilities

### Monitoring

- **Enable logging** and configure appropriate log levels
- **Monitor session statistics** using `action_mcp:stats`
- **Track tool usage** and performance metrics
- **Set up alerts** for error rates and response times

### Deployment

- **Use Falcon** for optimal performance with streaming workloads
- **Deploy on dedicated ports** or Unix sockets
- **Use reverse proxies** (Nginx, Apache) for SSL termination
- **Implement health checks** for your MCP endpoints
- **Use `mcp_vanilla.ru`** to avoid middleware conflicts

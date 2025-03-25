# ActionMCP

**ActionMCP** is a Ruby gem that provides essential tooling for building Model Context Protocol (MCP) capable servers in Ruby on Rails applications.

It offers base classes and helpers for creating MCP applications, making it easier to integrate your Ruby/Rails application with the MCP standard.

With ActionMCP, you can focus on your app's logic while it handles the boilerplate for MCP compliance.

## Introduction

**Model Context Protocol (MCP)** is an open protocol that standardizes how applications provide context to large language models (LLMs).

Think of it as a universal interface for connecting AI assistants to external data sources and tools.

MCP allows AI systems to plug into various resources in a consistent, secure way, enabling two-way integration between your data and AI-powered applications.

This means an AI (like an LLM) can request information or actions from your application through a well-defined protocol, and your app can provide context or perform tasks for the AI in return.

**ActionMCP** is targeted at developers building MCP-enabled applications.
It simplifies the process of integrating Ruby and Rails apps with the MCP standard by providing a set of base classes and an easy-to-use server interface.

Instead of implementing MCP support from scratch, you can subclass and configure the provided **Prompt**, **Tool**, and **ResourceTemplate** classes to expose your app's functionality to LLMs. 

ActionMCP handles the underlying MCP message format and routing, so you can adhere to the open standard with minimal effort.

In short, ActionMCP helps you build an MCP server (the component that exposes capabilities to AI) more quickly and with fewer mistakes.

## Installation

To start using ActionMCP, add it to your project:

- **Using Bundler (Rails or Ruby projects):** Add the gem to your Gemfile and run bundle install:

  ```bash
  $ bundle add actionmcp
  ```

This will load the ActionMCP library so you can start defining MCP prompts, tools, and resources in your application.

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
  end
end
```

For dynamic versioning, consider adding the `rails_app_version` gem.

## Engine and Mounting

ActionMCP is implemented as a Rails engine, which means it can be mounted in your application's routes.
The engine provides no authentication or authorization by default, so you'll need to handle that in your application for now.

To mount the ActionMCP engine in your routes, add the following line to your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount ActionMCP::Engine => "/action_mcp"
end
```

## Generators

ActionMCP includes Rails generators to help you quickly set up your MCP server components.

You can generate the base classes for your MCP Prompt and Tool using the following command:

```bash
bin/rails action_mcp:install:migrations  # to copy the migrations
bin/rails generate action_mcp:install 
```

This will create the base application classes in your app directory.

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

```markdown
## Profiles

ActionMCP supports a flexible profile system that allows you to selectively expose tools, prompts, and resources based on different usage scenarios. This is particularly useful for applications that need different MCP capabilities for different contexts (e.g., public API vs. admin interface).

### Understanding Profiles

Profiles are named configurations that define:

- Which tools are available
- Which prompts are accessible
- Which resources can be accessed
- Configuration options like logging level and change notifications

By default, ActionMCP includes two profiles:
- `default`: Exposes all tools, prompts, and resources
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
    - calculator_tool
    - weather_tool
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
ActionMCP.configuration.use_profile(:api_only)

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

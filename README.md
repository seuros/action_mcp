# ActionMCP

**ActionMCP** is a Ruby gem that provides essential tooling for building Model Context Protocol (MCP) capable servers. 

It offers base classes and helpers for creating MCP applications, making it easier to integrate your Ruby/Rails application with the MCP standard. 

With ActionMCP, you can focus on your app's logic while it handles the boilerplate for MCP compliance.

## Introduction

**Model Context Protocol (MCP)** is an open protocol that standardizes how applications provide context to large language models (LLMs) ([Introduction - Model Context Protocol](https://modelcontextprotocol.io/introduction#:~:text=MCP%20is%20an%20open%20protocol,different%20data%20sources%20and%20tools)). 

Think of it as a universal interface for connecting AI assistants to external data sources and tools. 

MCP allows AI systems to plug into various resources in a consistent, secure way, enabling two-way integration between your data and AI-powered applications ([Introducing the Model Context Protocol \ Anthropic](https://www.anthropic.com/news/model-context-protocol#:~:text=The%20Model%20Context%20Protocol%20is,that%20connect%20to%20these%20servers)). 

This means an AI (like an LLM) can request information or actions from your application through a well-defined protocol, and your app can provide context or perform tasks for the AI in return.

**ActionMCP** is targeted at developers building MCP-enabled applications. 
It simplifies the process of integrating Ruby and Rails apps with the MCP standard by providing a set of base classes and an easy-to-use server interface. 

Instead of implementing MCP support from scratch, you can subclass and configure the provided **Prompt**, **Tool**, and **Resource** classes to expose your app’s functionality to LLMs. 

ActionMCP handles the underlying MCP message format and routing, so you can adhere to the open standard with minimal effort. 

In short, ActionMCP helps you build an MCP server (the component that exposes capabilities to AI) more quickly and with fewer mistakes.

## Installation

To start using ActionMCP, add it to your project:

- **Using Bundler (Rails or Ruby projects):** Add the gem to your Gemfile and run bundle install:
  
  execute:
  ```
  $ bundle add actionmcp
  ```

After installing, include the gem in your code by requiring it:

This will load the ActionMCP library so you can start defining MCP prompts, tools, and resources in your application.

## Core Components

ActionMCP provides three core abstractions to streamline MCP server development: **Prompt**, **Tool**, and **Resource**. 
These correspond to key MCP concepts and let you define what context or capabilities your server exposes to LLMs. 
Below is an overview of each component and how you might use it:

### Configuration
ActionMCP is configured via config.action_mcp in your Rails application. 
By default, the name is set to your application's name and the version defaults to "0.0.1". 
You can override these settings in your configuration (e.g., in config/application.rb):
```ruby
module Tron
  class Application < Rails::Application
    config.action_mcp.name = "Friendly MCP (Master Control Program)"  # defaults to Rails.application.name
    config.action_mcp.version = "1.2.3"                 # defaults to "0.0.1"
    config.action_mcp.logging_enabled = true            # defaults to true
    config.action_mcp.logging_level = :info             # defaults to :info, can be :debug, :info, :warn, :error, :fatal
  end
end
```
The `logging_level` option configures the verbosity of the logs. It can be set to `:debug`, `:info`, `:warn`, `:error`, or `:fatal`. The default value is `:info`.

For dynamic versioning, consider adding the rails_app_version gem.

## Generators

ActionMCP includes Rails generators to help you quickly set up your MCP server components. You can generate the base classes for your MCP Prompt and Tool using the following commands.

To generate both the ApplicationPrompt and ApplicationTool files in your application, run:

```bash
bin/rails generate action_mcp:install 
```

This command will create:
•	app/prompts/application_prompt.rb
•	app/tools/application_tool.rb

### Generate a New Prompt

Run the following command to generate a new prompt class:

```bash
bin/rails generate action_mcp:prompt AnalyzeCode
```
This command will create a file at app/prompts/analyze_code_prompt.rb with content similar to:

```ruby
class AnalyzeCodePrompt < ApplicationPrompt
  # Override the prompt_name (otherwise we'd get "analyze-code")
  prompt_name "analyze-code"

  # Provide a user-facing description for your prompt.
  description "Analyze code for potential improvements"

  # Configure arguments via the new DSL
  argument :language, description: "Programming language", default: "Ruby"
  argument :code, description: "Code to explain", required: true

  # Add validations (note: "Ruby" is not allowed per the validation)
  validates :language, inclusion: { in: %w[C Cobol FORTRAN] }
end
```

## Generate a New Tool
Similarly, run the following command to generate a new tool class:

```bash
bin/rails generate action_mcp:tool CalculateSum
```

This command will create a file at app/tools/calculate_sum_tool.rb with content similar to:

```ruby
class CalculateSumTool < ApplicationTool
  tool_name "calculate-sum"
  description "Calculate the sum of two numbers"

  property :a, type: "number", description: "First number", required: true
  property :b, type: "number", description: "Second number", required: true
  
  def call
    render_text(a + b)
  end
end
```

### ActionMCP::Prompt

A **Prompt** defines a question or request that an LLM can make to your application. It encapsulates the input parameters required for the request and any validations that need to be performed.

For example, you might define a prompt called "analyze-code" that takes a code snippet as input and returns an analysis of the code.

### ActionMCP::Tool

A **Tool** defines an action that your application can perform on behalf of an LLM. It encapsulates the input parameters required for the action and any logic that needs to be executed.

For example, you might define a tool called "execute-command" that takes a shell command as input and executes it on the server, returning the output. This could be used to retrieve system information, run scripts, or perform other administrative tasks.

### ActionMCP::Resource

I dont need this for now

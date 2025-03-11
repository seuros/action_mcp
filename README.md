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

  ```bash
  $ bundle add actionmcp
  ```

This will load the ActionMCP library so you can start defining MCP prompts, tools, and resources in your application.

## Core Components

ActionMCP provides three core abstractions to streamline MCP server development: **Prompt**, **Tool**, and **Resource**. 

These correspond to key MCP concepts and let you define what context or capabilities your server exposes to LLMs. 

Note that ActionMCP requires a Rails application; it is not meant for standalone Ruby apps.

### Configuration

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

### Engine

ActionMCP is implemented as a Rails engine, which means it can be mounted in your application's routes.
The engine provides no authentication or authorization by default, so you'll need to handle that in your application for now.

To mount the ActionMCP engine in your routes, add the following line to your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount ActionMCP::Engine => "/action_mcp"
end
```

### Generators

ActionMCP includes Rails generators to help you quickly set up your MCP server components. 

You can generate the base classes for your MCP Prompt and Tool using the following command:

```bash
bin/rails generate action_mcp:install 
```

This command will create:
- `app/prompts/application_prompt.rb`
- `app/tools/application_tool.rb`

#### Generate a New Prompt

Run the following command to generate a new prompt class:

```bash
bin/rails generate action_mcp:prompt AnalyzeCode
```

This command will create a file at `app/prompts/analyze_code_prompt.rb` with content similar to:

```ruby
class AnalyzeCodePrompt < ApplicationPrompt
  # Override the prompt_name (otherwise we'd get "analyze_code")
  prompt_name "analyze-code"

  # Provide a user-facing description for your prompt.
  description "Analyze code for potential improvements"

  # Configure arguments via the new DSL
  argument :language, description: "Programming language", default: "Ruby"
  argument :code, description: "Code to explain", required: true

  # Add validations
  validates :language, inclusion: { in: %w[Ruby C Cobol FORTRAN] }
  
  def call
    # Implement your prompt logic here
    render_text("Analyzing #{language} code: #{code}")
  end
end
```

#### Generate a New Tool

Similarly, run the following command to generate a new tool class:

```bash
bin/rails generate action_mcp:tool CalculateSum
```

This command will create a file at `app/tools/calculate_sum_tool.rb` with content similar to:

```ruby
class CalculateSumTool < ApplicationTool
  tool_name "calculate_sum"
  description "Calculate the sum of two numbers"

  property :a, type: "number", description: "First number", required: true
  property :b, type: "number", description: "Second number", required: true
  
  def call
    render_text(a + b)
  end
end
```

### ActionMCP::Prompt

A **Prompt** defines a question or request that an LLM can make to your application. It encapsulates the input parameters required for the request and any validations that need to be performed. For example, you might define a prompt called "analyze-code" that takes a code snippet as input and returns an analysis of the code.

### ActionMCP::Tool

A **Tool** defines an action that your application can perform on behalf of an LLM. It encapsulates the input parameters required for the action and any logic that needs to be executed. For example, you might define a tool called "execute-command" that takes a shell command as input and executes it on the server, returning the output. This could be used to retrieve system information, run scripts, or perform other administrative tasks.

### ActionMCP::Resource

*I don't need this for now.*

## Usage Example

Both Tool and Prompt classes are based on ActiveModel, which means they share the same initialization and validation behavior. You can instantiate them with initial values, update their attributes later if necessary, and then call the `call` method to execute the logic defined in your class.

### Example for a Prompt

```ruby
# Instantiate the prompt with initial values
analyze_prompt = AnalyzeCodePrompt.new(language: "Ruby", code: "def hello; puts 'Hello, world!'; end")

# Optionally update attributes later:
analyze_prompt.code = "def goodbye; puts 'Goodbye!'; end"

# Validate the prompt before calling it
if analyze_prompt.valid?
  result = analyze_prompt.call # => #<ActionMCP::Content::Text:0x00000001239398c8 @text="The code you provided is written in Ruby and looks great!", @type="text">
  puts result.to_h  # => {type: "text", text: "The code you provided is written in Ruby and looks great!"}
else
  puts analyze_prompt.errors.full_messages
end
```

### Example for a Tool

```ruby
# Instantiate the tool with initial values
sum_tool = CalculateSumTool.new(a: 5, b: 10)

# Optionally update attributes later:
sum_tool.a = 15
sum_tool.b = 20

# Validate the tool before calling it
if sum_tool.valid?
  result = sum_tool.call # => #<ActionMCP::Content::Text:0x0000000124cfaba0 @text="35.0", @type="text">
  puts result.to_h  # => {type: "text", text: "35.0"}
else
  puts sum_tool.errors.full_messages
end
```

These examples show that both prompts and tools follow a consistent pattern for initialization, validation, and execution, making it easy to integrate them into your application logic.

## Examples & Important Notes

- **Running the Dummy App:**
  After creating the database with `bin/rails db:prepare`, you can run the dummy application using:
  ```bash
  bin/rails s
  ```
  This allows you to test and interact with the MCP server from the dummy environment. 
- **Inspecting the App:**
  You can use the mcp inspector to test your app ```npx @modelcontextprotocol/inspector```
  the path by default will be http://localhost:3000/action_mcp
  

- **Postgres on macOS:**
  If you are using Postgres on macOS, you may encounter issues due to a bug in Puma and the `pg` gem. To work around this, set the following environment variables:
  ```bash
  export PGGSSENCMODE=disable
  export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
  ```
  More details can be found in [Rails Issue #38560](https://github.com/rails/rails/issues/38560).

- **Notifiers:**
  ActionMCP works with the ActiveCable Postgres notifier by default, but its architecture is flexible enough to support other notifier implementations.

- **API Stability:**
  The ActionMCP API is stable, though it is acceptable for improvements and changes to be introduced as we move forward. This approach ensures the gem stays modern and adaptable to evolving requirements.

## Conclusion

ActionMCP empowers developers to build MCP-compliant servers efficiently by handling the standardization and boilerplate associated with integrating with LLMs. With built-in generators, clear configuration options, robust usage examples, and important deployment considerations, it is designed to accelerate development and integration work while remaining flexible for future enhancements.

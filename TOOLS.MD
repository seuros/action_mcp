# ActionMCP Tools Guide

## 🚀 START HERE: Use the Generator!

**Don't write tools from scratch!** Use the Rails generator:

```bash
# Simplest tool - just give it a name
bin/rails generate action_mcp:tool AddNumbers

# Tool that only reads data
bin/rails generate action_mcp:tool GetUserInfo --read-only

# Tool that calls external APIs
bin/rails generate action_mcp:tool FetchWeather --read-only --open-world

# Tool that changes data
bin/rails generate action_mcp:tool CreateOrder --destructive

# Tool with custom properties
bin/rails generate action_mcp:tool SendEmail to:string subject:string body:string --destructive --open-world
```

## Generator Options Explained

- `--read-only` - Tool only reads, doesn't change anything
- `--destructive` - Tool can delete or modify data
- `--idempotent` - Running twice with same input = same result
- `--open-world` - Tool talks to external systems (APIs, files, etc.)
- `--title "Pretty Name"` - Human-friendly name for UI display

## What the Generator Creates

Running `bin/rails generate action_mcp:tool CalculateSum` creates:

**File:** `app/mcp/tools/calculate_sum_tool.rb`

```ruby
# frozen_string_literal: true

class CalculateSumTool < ApplicationMCPTool
  tool_name "calculate_sum"
  description "Calculate sum"

  property :input, type: "string", description: "Input", required: true

  def perform
    render(text: "Processing input")

    # Optional outputs:
    # render(audio: "<base64_data>", mime_type: "audio/mpeg")
    # render(image: "<base64_data>", mime_type: "image/png")
    # render(resource: "file://path", mime_type: "application/json", text: "{}")
    # render(resource: "file://path", mime_type: "application/octet-stream", blob: "<base64_data>")
  rescue => e
    render(error: ["Error: #{e.message}"])
  end
end
```

## Three Complete Examples

### 1. Calculator Tool (Simplest)

**Generate:**
```bash
bin/rails generate action_mcp:tool AddNumbers a:number b:number
```

**Modify the `perform` method:**
```ruby
def perform
  result = a + b
  render(text: "#{a} + #{b} = #{result}")
end
```

That's it! The tool now adds two numbers.

### 2. Database Reader Tool

**Generate:**
```bash
bin/rails generate action_mcp:tool GetUserCount --read-only
```

**Modify the `perform` method:**
```ruby
def perform
  count = User.count
  render(text: "Total users: #{count}")
end
```

### 3. Weather API Tool

**Generate:**
```bash
bin/rails generate action_mcp:tool GetWeather city:string --read-only --open-world
```

**Modify the `perform` method:**
```ruby
def perform
  # Your API call here
  weather_data = fetch_weather_for(city)
  render(text: "Weather in #{city}: #{weather_data[:temp]}°C, #{weather_data[:description]}")
rescue => e
  render(error: ["Could not fetch weather: #{e.message}"])
end

private

def fetch_weather_for(city)
  # Your HTTP request logic here
  { temp: 22, description: "Sunny" }
end
```

## The Core Pattern

Every tool follows this pattern:

```ruby
class YourToolNameTool < ApplicationMCPTool
  tool_name "your_tool_name"        # Required: unique identifier
  description "What this tool does"  # Required: explain the purpose
  
  # Define inputs (properties become method names!)
  property :user_id, type: "string", description: "The user's ID", required: true
  property :limit, type: "number", description: "Max results", required: false
  
  def perform
    # Your logic here
    # Access properties as methods: user_id, limit
    
    # Return results using render
    render(text: "Your result here")
  end
end
```

## Property Types

- `"string"` - Text input
- `"number"` - Numeric input (integer or float)
- `"boolean"` - true/false
- `"array"` - List of items
- `"object"` - Complex nested data

## Render Options

You can call `render` multiple times to show progress:

```ruby
def perform
  render(text: "Starting process...")
  
  # Do some work
  result = process_data
  
  render(text: "Processing complete!")
  render(text: "Result: #{result}")
  
  # You can also render:
  render(image: base64_image_data, mime_type: "image/png")
  render(audio: base64_audio_data, mime_type: "audio/mpeg")
  render(error: ["Something went wrong"])
end
```

## Adding Validation

Use standard Rails validations:

```ruby
class CreateUserTool < ApplicationMCPTool
  property :email, type: "string", description: "User email", required: true
  property :age, type: "number", description: "User age", required: true
  
  # Rails validations work!
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :age, numericality: { greater_than: 0, less_than: 150 }
  
  def perform
    # Validation runs automatically before perform
    User.create!(email: email, age: age)
    render(text: "User created successfully")
  end
end
```

## Testing Your Tool

### 1. Check if your tool is registered:
```bash
bundle exec rails action_mcp:list_tools
```

### 2. Test with MCP Inspector:
```bash
npx @modelcontextprotocol/inspector --url http://localhost:3000/action_mcp
```

### 3. Write a test:
```ruby
# test/mcp/tools/your_tool_test.rb
require "test_helper"

class YourToolTest < ActiveSupport::TestCase
  test "does the thing" do
    tool = YourTool.new(input: "test")
    result = tool.call
    
    assert_equal "Expected output", result.first[:text]
  end
end
```

## Quick Checklist

✅ Used the generator? `bin/rails generate action_mcp:tool ToolName`  
✅ Tool inherits from `ApplicationMCPTool`?  
✅ Has unique `tool_name`?  
✅ Has clear `description`?  
✅ Properties match what you use in `perform`?  
✅ Using `render` to return results?  
✅ Tool shows up in `rails action_mcp:list_tools`?  

## Common Issues

**Tool not showing up in list?**
- Make sure it inherits from `ApplicationMCPTool`
- Check the file is in `app/mcp/tools/`
- Restart your server

**Getting "undefined method" errors?**
- Property names become method names: `property :user_id` → use `user_id` in perform
- Check spelling matches exactly

**Validation errors?**
- Required properties must be provided
- Check your validates rules
- Error will show which validation failed

## Remember

1. **Always use the generator** - It sets up everything correctly
2. **Properties become methods** - `property :name` means you can use `name` in perform
3. **Multiple renders are fine** - Show progress with multiple render calls
4. **Errors are caught** - The rescue block is already there for you

That's it! You now know how to create MCP tools. Start with the generator and modify from there.
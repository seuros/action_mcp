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

## Consent Management for Sensitive Tools

Some tools perform sensitive operations and require explicit user consent:

```ruby
class DeleteUserTool < ApplicationMCPTool
  tool_name "delete_user"
  description "Delete a user account"
  
  # Require explicit consent before execution
  requires_consent!
  
  property :user_id, type: "string", description: "User ID to delete", required: true
  
  def perform
    # This code only runs after user grants consent
    user = User.find(user_id)
    user.destroy!
    render(text: "User #{user.name} has been deleted")
  end
end
```

**When to use consent:**
- File system operations
- Database modifications
- External API calls that change data
- Any destructive operations

**Consent Flow:**
1. Tool called without consent → Returns error -32002
2. Client grants consent for specific tool
3. Tool executes normally for that session

```ruby
# Managing consent programmatically
session.consent_granted_for?("delete_user")  # Check consent
session.grant_consent("delete_user")         # Grant consent
session.revoke_consent("delete_user")        # Revoke consent
```

## Testing Your Tool

### 1. Check if your tool is registered:
```bash
bundle exec rails action_mcp:list_tools
```

### 2. Test with MCP Inspector:
```bash
# Start your MCP server
bundle exec rails s -c mcp.ru -p 62770

# In another terminal, run the inspector
npx @modelcontextprotocol/inspector --url http://localhost:62770
```

### 3. Write a test:
```ruby
# test/mcp/tools/your_tool_test.rb
require "test_helper"
require "action_mcp/test_helper"

class YourToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper
  
  test "does the thing" do
    assert_tool_findable("your_tool")
    result = execute_tool("your_tool", input: "test")
    assert_tool_output(result, "Expected output")
  end
  
  test "consent required tool" do
    # Tool should require consent first
    assert_raises ActionMCP::ConsentRequiredError do
      execute_tool("delete_user", user_id: "123")
    end
    
    # Grant consent and try again
    session.grant_consent("delete_user")
    result = execute_tool("delete_user", user_id: "123")
    assert_tool_output(result, "User deleted")
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

## Error Handling and Clear Messages

Tools should return clear error messages to the LLM using the `render` method:

```ruby
class FileReaderTool < ApplicationMCPTool
  def perform
    unless File.exist?(file_path)
      render(error: ["File not found: #{file_path}"])
      return
    end
    
    begin
      content = File.read(file_path)
      render(text: "File contents: #{content}")
    rescue => e
      render(error: ["Could not read file: #{e.message}"])
    end
  end
end
```

**Error Types:**
- **Validation errors** - Automatic from property validation
- **Consent errors** - Code -32002 when consent required
- **Tool errors** - Use `render(error: ["Clear message for LLM"])`
- **Success responses** - Use `render(text: "Success message")`

## Common Issues

**Tool not showing up in list?**
- Make sure it inherits from `ApplicationMCPTool`
- Check the file is in `app/mcp/tools/`
- Restart your server
- Verify with `bundle exec rails action_mcp:list_tools`

**Getting "undefined method" errors?**
- Property names become method names: `property :user_id` → use `user_id` in perform
- Check spelling matches exactly
- Properties are automatically validated and accessible

**Validation errors?**
- Required properties must be provided
- Check your validates rules
- Error will show which validation failed
- Use Rails validations for complex rules

**Consent errors?**
- Tool returns error -32002 when consent required
- Grant consent using `session.grant_consent(tool_name)`
- Consent is session-scoped and persists until revoked

**Session not found?**
- Ensure session exists in session store
- Check session ID is properly passed in headers
- Use fixtures in tests for consistent sessions

## Advanced Features

### Multiple Output Types
```ruby
def perform
  # Text output
  render(text: "Processing started...")
  
  # Image output
  chart_data = generate_chart
  render(image: chart_data, mime_type: "image/png")
  
  # Audio output
  audio_data = text_to_speech("Processing complete")
  render(audio: audio_data, mime_type: "audio/mpeg")
  
  # File resource
  render(resource: "file://output.json", 
         mime_type: "application/json",
         text: results.to_json)
end
```

### Authentication Context
```ruby
def perform
  # Access authenticated user
  if current_user
    render(text: "Hello, #{current_user.name}!")
  else
    render(text: "Hello, anonymous user!")
  end
  
  # Access other gateway identifiers
  if current_organization
    render(text: "Organization: #{current_organization.name}")
  end
end
```

### Profile-Based Tool Exposure
```ruby
# Only available in specific profiles
# Configure in config/mcp.yml:
# admin_profile:
#   tools:
#     - admin_tool
#     - delete_user
```

## Performance Tips

1. **Use database indexes** for property lookups
2. **Cache expensive operations** within the perform method
3. **Limit output size** for large datasets
4. **Use background jobs** for long-running operations
5. **Stream progress** with multiple render calls

## Security Best Practices

1. **Validate all inputs** using Rails validations
2. **Use consent for sensitive operations**
3. **Never expose secrets** in tool outputs
4. **Implement proper authorization** in perform method
5. **Sanitize user inputs** before database queries
6. **Use parameterized queries** to prevent SQL injection

## Remember

1. **Always use the generator** - It sets up everything correctly
2. **Properties become methods** - `property :name` means you can use `name` in perform
3. **Multiple renders are fine** - Show progress with multiple render calls
4. **Consent protects users** - Use for any destructive operations
5. **Test thoroughly** - Use TestHelper for comprehensive testing
6. **Context matters** - Error messages adapt to HTTP vs direct calls

That's it! You now know how to create powerful, secure MCP tools. Start with the generator and build from there.
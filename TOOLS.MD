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
    report_error("Error: #{e.message}")
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
  report_error("Could not fetch weather: #{e.message}")
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
- `"object"` - ⚠️ **Limited support** - See Input Schema Limitations below

## ⚠️ Input Schema Limitations

**Important:** The MCP specification currently only supports **flat, single-level** input schemas. While JSON Schema technically allows nested objects, the MCP spec intentionally keeps input parameters at one level.

### Why Flat Schemas?

1. **LLM Performance** - Language models work better with flat parameter lists
2. **Spec Compliance** - Prevents drift from official MCP specification
3. **SDK Compatibility** - Strict validation in newer SDKs will reject nested structures

### Complex Data Workaround

For complex configuration or nested data, use the **JSON string pattern**:

```ruby
class ConfigUpdateTool < ApplicationMCPTool
  tool_name "config_update"
  description "Update multiple configuration properties"

  # Use JSON string instead of nested object
  property :config_json, type: "string", description: "JSON string of configuration object"

  def perform
    # Parse the JSON string to get your complex object
    config = JSON.parse(config_json)

    # Now you can work with nested data
    config.each do |key, value|
      update_config(key, value)
    end

    render(text: "Updated #{config.keys.length} configuration properties")
  end
end
```

**Example tool call:**
```json
{
  "config_json": "{\"database_host\": \"localhost\", \"cache_ttl\": 3600, \"debug_mode\": true}"
}
```

### Spec Compliance Notes

- **Use `"number"` not `"float"`** - `"float"` is not valid JSON Schema
- **Test with MCP Inspector** - Frontier models may "fix" invalid schemas, but strict SDKs will reject them
- **Avoid `type: "object"`** for input properties unless you're implementing experimental features

## Additional Properties (Dynamic Inputs)

Tools can accept extra parameters beyond those explicitly defined using `additional_properties`:

```ruby
class FlexibleApiTool < ApplicationMCPTool
  tool_name "flexible_api"
  description "API caller that accepts dynamic parameters"

  # Define core properties
  property :endpoint, type: "string", description: "API endpoint", required: true
  property :method, type: "string", description: "HTTP method", default: "GET"

  # Allow any additional properties
  additional_properties true

  def perform
    # Access defined properties normally
    url = endpoint
    http_method = method

    # Access additional properties through special method
    extra_params = additional_params

    render(text: "Calling #{url} with method #{http_method}")
    extra_params.each do |key, value|
      render(text: "Extra param #{key}: #{value}")
    end
  end
end
```

**Additional Properties Options:**

```ruby
# Allow any additional properties of any type
additional_properties true

# Explicitly disallow additional properties
additional_properties false

# Allow additional properties but restrict to strings
additional_properties({"type" => "string"})

# Allow additional properties with more complex schemas
additional_properties({
  "type" => "object",
  "properties" => {
    "timeout" => {"type" => "number"}
  }
})
```

**Use Cases for Additional Properties:**

1. **API Proxy Tools** - Forward arbitrary parameters to external APIs
2. **Configuration Tools** - Accept flexible configuration options
3. **Open World Tools** - Handle unpredictable input structures
4. **Dynamic Data Processing** - Work with varying data schemas

**Example Usage:**

```json
// Tool call with additional properties
{
  "endpoint": "/api/users",
  "method": "POST",
  "auth_token": "secret123",    // Additional property
  "timeout": 5000,             // Additional property
  "debug": true                // Additional property
}
```

## Output Schema (Structured Responses)

Tools can define structured output schemas to provide predictable, validated responses that LLMs can reliably parse and use:

```ruby
class WeatherTool < ApplicationMCPTool
  tool_name "weather"
  description "Get weather with structured output"

  property :location, type: "string", required: true

  # Define the structure of your tool's output
  output_schema do
    boolean :success, required: true
    string :message

    object :current do
      number :temperature, required: true
      string :condition, required: true
      number :humidity, minimum: 0, maximum: 100
    end

    array :forecast do
      object do
        string :date, format: "date", required: true
        number :high, required: true
        number :low, required: true
      end
    end
  end

  def perform
    # Return structured data that matches your schema
    render structured: {
      success: true,
      message: "Weather retrieved for #{location}",
      current: { temperature: 22.5, condition: "Sunny", humidity: 65 },
      forecast: [
        { date: "2025-01-01", high: 25, low: 18 }
      ]
    }
  end
end
```

### Output Schema DSL Methods

- `string :name` - Text property
- `number :price` - Numeric property
- `boolean :active` - True/false property
- `object :data do...end` - Nested object with properties
- `array :items do...end` - Array with item schema
- `additional_properties true` - Allow extra properties

### Schema Constraints

- `required: true` - Property must be present
- `minimum: 0, maximum: 100` - Numeric bounds
- `format: "date"` - String format (date, date-time, uri, email)
- `enum: ["option1", "option2"]` - Allowed values
- `default: "value"` - Default value

### Real Examples

**Complex nested schema:** See `test/dummy/app/mcp/tools/weather_tool.rb`
- Shows nested objects, arrays, timestamps
- Demonstrates optional vs required fields
- Includes metadata and forecast arrays

**Configuration schema:** See `test/dummy/app/mcp/tools/config_update_tool.rb`
- Shows flat and nested object patterns
- Array of simple string warnings
- Success/message response pattern

### When to Use Output Schemas

✅ **Use output schemas when:**
- LLMs need to parse your data programmatically
- Building multi-step workflows with tool chaining
- Providing structured data (JSON, database records)
- Creating consistent API-like responses

❌ **Skip output schemas for:**
- Simple text responses or status messages
- Creative content generation
- Progress updates during execution
- Human-readable summaries

**Key benefit:** LLMs can reliably extract specific data from your tool's response instead of parsing free-form text.

### Schema-Data Alignment (MCP Compliance)

Per MCP specification, servers **MUST** provide structured results that conform to the declared `output_schema`. Your data structure must exactly match your schema declaration.

**Named objects in arrays create wrappers:**

```ruby
output_schema do
  array :items do
    object :entry do        # Named object = items have "entry" wrapper
      property :name, type: "string"
      property :value, type: "number"
    end
  end
end

def perform
  # Data MUST include the "entry" wrapper to match schema
  render structured: {
    items: [
      { entry: { name: "foo", value: 42 } }
    ]
  }
end
```

**Enable validation to catch mismatches:**

ActionMCP can validate structured content against your schema. Add `json_schemer` to your Gemfile:

```ruby
# Gemfile
gem 'json_schemer', '~> 2.4'
```

Then enable validation:

```ruby
# config/environments/development.rb
config.action_mcp.validate_structured_content = true
```

When enabled, `render structured:` will raise `ActionMCP::StructuredContentValidationError` if data doesn't match schema.

### Input vs Output Schema Differences

**Important distinction:**

| Feature | Input Schema | Output Schema |
|---------|--------------|---------------|
| **Nesting Level** | Flat only (single level) | Unlimited nesting depth |
| **Object Types** | Discouraged/Limited | Fully supported |
| **Spec Status** | Strictly defined | More flexible |
| **Why Different?** | LLMs handle flat params better | LLMs need structured data parsing |

**Input schemas** must be flat because:
- LLMs process simple parameter lists more reliably
- Prevents infinite nesting complexity (HomeAssistant configs going 10 levels deep)
- Maintains MCP specification compliance

**Output schemas** can be deeply nested because:
- LLMs need to parse complex returned data structures
- Response parsing is different from parameter understanding
- Tools often return rich, structured data (APIs, databases, etc.)

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

  # For errors, use the helper method:
  report_error("Something went wrong")
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

**⚠️ Important Testing Notes:**

- **Always test with MCP Inspector** for true spec compliance validation
- **Don't rely solely on Claude Code testing** - Frontier models will "fix" broken schemas and missing fields, giving false confidence
- **SDK strictness is increasing** - What works today with "vibed" clients may break tomorrow with strict validation
- **Historical example:** `"float"` and `"array_float"` types worked until the JavaScript SDK was patched to enforce proper JSON Schema types

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
      report_error("File not found: #{file_path}")
      return
    end

    begin
      content = File.read(file_path)
      render(text: "File contents: #{content}")
    rescue => e
      report_error("Could not read file: #{e.message}")
    end
  end
end
```

**Error Types:**
- **Validation errors** - Automatic from property validation
- **Consent errors** - Code -32002 when consent required
- **Tool errors** - Use `report_error("Clear message for LLM")`
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

## Resumable Tools (Long-Running Operations)

Tools can now be resumable, supporting long-running operations with progress tracking, human-in-the-loop interaction, and automatic resilience via Rails 8.1's `ActiveJob::Continuable` feature.

### When to Use Resumable Tools

✅ **Use resumable tools for:**
- Tools that take more than a few seconds to complete
- Multi-step processes requiring user input
- Operations that might be interrupted (deployments, network issues)
- Tools needing progress updates during execution
- Complex workflows with multiple checkpoints

❌ **Don't use for:**
- Quick operations (< 1 second)
- Simple read-only tools
- Operations that must complete atomically

### Enabling Resumable Steps

Define resumable steps in your tool using the DSL:

```ruby
class LongRunningToolTool < ApplicationMCPTool
  tool_name "long_running_tool"
  description "Tool with progress tracking and resumption"

  property :file_path, type: "string", required: true
  property :timeout, type: "number", default: 300

  # Define checkpoints where the tool can be resumed
  resumable_steps do
    step :validate_input, "Validating inputs"
    step :prepare_environment, "Setting up environment"
    step :process_data, "Processing data"
    step :save_results, "Saving results"
  end

  def perform
    # Work on the first step
    render(text: "Starting operation...")

    # Validate inputs
    validate_file_exists(file_path)

    # Report progress
    report_progress!(percent: 10, message: "Validated inputs")

    # Process the file
    result = process_file(file_path)

    # Update progress mid-operation
    report_progress!(percent: 50, message: "File processing complete")

    # If human input is needed, request it
    if result[:needs_confirmation]
      request_input!(
        prompt: "Do you want to save these changes?",
        context: { changes: result[:changes].length }
      )

      # After input is provided via tasks/resume, execution resumes here
      save_changes(result)
    end

    # Final update
    report_progress!(percent: 100, message: "Operation complete")
    render(text: "Successfully processed #{result[:items_processed]} items")
  end

  private

  def validate_file_exists(path)
    unless File.exist?(path)
      report_error("File not found: #{path}")
    end
  end

  def process_file(path)
    # Your processing logic here
    { items_processed: 100, needs_confirmation: true, changes: [] }
  end

  def save_changes(result)
    # Process the user input from continuation_state
    # This executes after tasks/resume is called with the input
  end
end
```

### Progress Reporting

Update progress while the tool is executing:

```ruby
def perform
  total_items = data.length

  data.each_with_index do |item, index|
    process(item)

    # Report progress
    percent = ((index + 1) / total_items.to_f * 100).round
    report_progress!(
      percent: percent,
      message: "Processing #{index + 1} of #{total_items}"
    )
  end

  render(text: "Processed all #{total_items} items")
end
```

### Human-in-the-Loop Workflows

Request user input to continue execution:

```ruby
def perform
  # Perform initial analysis
  analysis = analyze_data(input)

  # If we need user confirmation
  if analysis[:requires_decision]
    request_input!(
      prompt: analysis[:question],
      context: {
        recommendations: analysis[:recommendations],
        risk_level: analysis[:risk_level]
      }
    )

    # Execution stops here until tasks/resume is called
    # with user's input in the 'input' parameter
  end

  # This code runs after tasks/resume provides input
  user_input = continuation_state[:input]
  process_decision(user_input)

  render(text: "Decision processed: #{user_input}")
end
```

### Client-Side Resume Flow

To resume a task that's awaiting input:

```bash
# Get the task status
curl -X POST http://localhost:62770/ \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: YOUR_SESSION_ID" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tasks/get",
    "params": {"taskId": "task-123"}
  }'

# When status is "input_required", resume with input
curl -X POST http://localhost:62770/ \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: YOUR_SESSION_ID" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tasks/resume",
    "params": {
      "taskId": "task-123",
      "input": {"decision": "proceed"}
    }
  }'
```

### Automatic Resilience

Resumable tools automatically handle failures with:

1. **Retry Logic** - Failed jobs retry with exponential backoff (up to 3 attempts)
2. **Step Persistence** - Last completed step is saved in the database
3. **Continuation State** - Tool state can be serialized and restored
4. **Task Status Updates** - Real-time progress via WebSocket notifications

The job automatically moves to a terminal state (`completed` or `failed`) even if the job crashes or is interrupted:

```ruby
# In your resumable tool
def perform
  @task = step(:load_task, task_id)
  return if @task.nil? || @task.terminal?

  @session = step(:validate_session, @task)
  return unless @session

  @tool = step(:prepare_tool, @session, tool_name, arguments)
  return unless @tool

  step(:execute_tool) do
    # Your tool code runs here with automatic resilience
    # If this step fails, it's retried or marked as failed
  end
end
```

### Testing Resumable Tools

```ruby
class YourResumableToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "tool can be resumed with input" do
    # Create a task for the resumable tool
    session = ActionMCP::Session.create!
    task = session.tasks.create!(
      id: "test-123",
      request_name: "your_tool",
      request_params: { input: "test" },
      status: "input_required"
    )

    # Simulate resuming with user input
    task.update(continuation_state: { input: { decision: "yes" } })
    task.resume_from_continuation!

    # Assert the resumed task completes
    assert task.reload.completed?
  end
end
```

### Best Practices

1. **Call `report_progress!` regularly** to keep clients informed
2. **Use meaningful step names** for debugging and monitoring
3. **Always handle `input_required` state** gracefully
4. **Store partial results** in continuation_state for recovery
5. **Validate input** when resuming from continuation
6. **Set reasonable timeouts** to avoid hanging jobs
7. **Log important transitions** between steps

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
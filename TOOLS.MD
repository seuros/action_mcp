# ActionMCP::Tool

## Overview
ActionMCP::Tool provides a framework for LLMs to interact with external systems. 
Each tool has a specific purpose, defined inputs (properties), and structured outputs.

## Core Components

### Tool Definition
- Each tool is a Ruby class inheriting from `ApplicationMCPTool`
- Required elements:
    - `title`: Human-readable title for the tool (optional, but recommended)
    - `description`: Explain what the tool does
    - `read_only`: If true, the tool does not modify its environment
    - `destructive`: If true, the tool may perform destructive updates
    - `idempotent`: If true, repeated calls with same args have no additional effect
    - `open_world`: If true, tool interacts with external entities
    - `property`: Define expected inputs with type information
    - `perform`: Core logic that executes the tool's function

### Rendering Output
Use these methods to return information:
- `render(text: "message")`: Return text responses
- `render(image: "base64_data", mime_type: "image/png")`: Return images
- `render(audio: "base64_data", mime_type: "audio/mpeg")`: Return audio
- `render(resource: "file://path/to/resource", mime_type: "application/json", text: "{}")`: Return resource with text content
- `render(resource: "file://path/to/resource", mime_type: "application/octet-stream", blob: "base64_data")`: Return resource with base64 encoded data
- `render(error: ["error_message"])`: Return errors

## Usage Pattern

1. **Input validation** happens automatically based on property definitions
2. **Tool execution** occurs in the `perform` method
3. **Response handling** uses `render` to format outputs
4. **Multiple renders** can be called to provide progressive information

## Example Tools

### Check Inventory
```ruby
class InventoryCheckTool < ApplicationMCPTool
  title "Inventory Check"
  description "Check the current stock level of a product"
  read_only
  idempotent

  property :product_id, type: "string", description: "The ID of the product", required: true
  validates :product_id, length: { is: 6 }
  
  def perform
    render(image: product_thumbnail(product_id), mime_type: "image/png")
    stock_level = get_stock_level(product_id)
    render(text: "The current stock level for product #{product_id} is #{stock_level}")
    if stock_level < 10
      render(text: "Warning: Low stock level for product #{product_id}")
    end
  rescue => e
    render(error: ["Could not retrieve stock level: #{e.message}"])
  end

  private
  # Implementation methods...
end
```

### Create Order
```ruby
class CreateOrderTool < ApplicationMCPTool
  title "Order Creation"
  description "Create a new order for a customer"
  destructive
  open_world

  property :customer_id, type: "string", description: "The ID of the customer", required: true
  property :product_ids, type: "array", description: "An array of product IDs to add to the order", required: true

  def perform
    order_id = create_order(customer_id, product_ids)
    render(text: "Successfully created order #{order_id} for customer #{customer_id} with products #{product_ids.join(', ')}")
  rescue => e
    render(error: ["Could not create order: #{e.message}"])
  end

  private
  # Implementation methods...
end
```

## Tool Annotation Keys

In DSL code, you use:
- `title "Human-Readable Name"`: Sets a human-readable title for the tool
- `read_only`: Indicates the tool does not modify its environment
- `destructive`: Indicates the tool may perform destructive updates
- `idempotent`: Indicates repeated calls with same args have no additional effect
- `open_world`: Indicates tool interacts with external entities

These are mapped in the protocol to these annotation keys:
- `title`: Human-readable title for the tool
- `readOnlyHint`: If true, the tool does not modify its environment
- `destructiveHint`: If true, the tool may perform destructive updates
- `idempotentHint`: If true, repeated calls with same args have no additional effect
- `openWorldHint`: If true, tool interacts with external entities

### Annotation Combinations and Best Practices

These annotations should be applied based on the tool's behavior:

1. **Read-Only Tools**
   - Use `read_only` for tools that only retrieve or compute data without modifying state
   - Examples: data retrieval, calculations, validations
   - Often paired with `idempotent` as read-only operations typically return the same result

2. **Destructive Tools**
   - Use `destructive` for tools that modify state in a way that can't be easily undone
   - Examples: deleting records, making permanent changes, sending emails
   - Should NOT be paired with `read_only` (mutually exclusive)

3. **Idempotent Tools**
   - Use `idempotent` for tools where repeated calls with the same arguments produce the same result
   - Examples: retrieval operations, creating records with explicit IDs
   - Can be combined with either `read_only` or `destructive`

4. **Open World Tools**
   - Use `open_world` for tools that interact with external systems
   - Examples: API calls, filesystem access, database operations
   - Common with both `read_only` (data fetching) and `destructive` (external mutations)

Common valid combinations:
- `read_only` + `idempotent`: Pure functions, data retrievers
- `destructive` + `idempotent`: Operations that create/update with predictable results
- `read_only` + `open_world`: External data fetchers
- `destructive` + `open_world`: External API calls that cause changes

## Key Implementation Notes

1. Use ActiveModel validations for input verification
2. Structure error handling with rescue blocks
3. Return meaningful error messages when operations fail
4. Chain multiple `render` calls for progressive responses
5. Include descriptive property definitions to guide parameter usage
6. Use callbacks to perform actions before, after, or around the tool's execution

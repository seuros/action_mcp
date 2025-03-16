# ActionMCP::Tool

## Overview
ActionMCP::Tool provides a framework for LLMs to interact with external systems. 
Each tool has a specific purpose, defined inputs (properties), and structured outputs.

## Core Components

### Tool Definition
- Each tool is a Ruby class inheriting from `ApplicationMCPTool`
- Required elements:
    - `description`: Explain what the tool does
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
  description "Check the current stock level of a product"

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
  description "Create a new order for a customer"

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

## Key Implementation Notes

1. Use ActiveModel validations for input verification
2. Structure error handling with rescue blocks
3. Return meaningful error messages when operations fail
4. Chain multiple `render` calls for progressive responses
5. Include descriptive property definitions to guide parameter usage

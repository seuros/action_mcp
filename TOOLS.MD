# TOOLS.MD

## Introduction

This document provides guidance on how to design and implement effective tools for use with Large Language Models (LLMs) within the ActionMCP framework. Tools are functions that enable LLMs to interact with external systems, perform computations, and take actions in the real world. Well-designed tools are essential for extending the capabilities of LLMs and enabling them to perform complex tasks.

## Tool Design Principles

*   Functionality and Purpose
*   Input and Output
*   Error Handling

## Tool Structure in ActionMCP

*   `ActionMCP::Tool` class
*   `tool_name` and `description` methods
*   `property` method for defining properties
*   `call` method for tool logic

## Example Tool Patterns

*   System Operations
*   API Integrations
*   Data Processing

## Best Practices

*   Provide clear, descriptive names and descriptions
*   Use detailed JSON Schema definitions for parameters
*   Include examples in tool descriptions to demonstrate how the model should use them
*   Implement proper error handling and validation
*   Use progress reporting for long operations
*   Keep tool operations focused and atomic
*   Document expected return value structures
*   Implement proper timeouts
*   Consider rate limiting for resource-intensive operations
*   Log tool usage for debugging and monitoring

## Security Considerations

*   Input validation
*   Access control
*   Error handling

## Tool Discovery and Updates

## Error Handling

## Testing Tools

## Examples

### Inventory Management Tool

A tool that allows the LLM to check the current stock level of a product.

```ruby
class InventoryCheckTool < ActionMCP::Tool
  description "Check the current stock level of a product"

  property :product_id, type: "string", description: "The ID of the product", required: true

  def call
    # In a real implementation, this would query a database or API
    stock_level = get_stock_level(product_id)
    render(text: "The current stock level for product #{product_id} is #{stock_level}")
  rescue => e
    render(error: "Could not retrieve stock level: #{e.message}")
  end

  private

  def get_stock_level(product_id)
    # Stub implementation
    rand(0..100)
  end
end
```

### Order Creation Tool

A tool that allows the LLM to create a new order for a customer.

```ruby
require 'securerandom'

class CreateOrderTool < ActionMCP::Tool
  description "Create a new order for a customer"

  property :customer_id, type: "string", description: "The ID of the customer", required: true
  property :product_ids, type: "array", description: "An array of product IDs to add to the order", required: true

  def call
    # In a real implementation, this would create a new order in a database or system
    order_id = create_order(customer_id, product_ids)
    render(text: "Successfully created order #{order_id} for customer #{customer_id} with products #{product_ids.join(', ')}")
  rescue => e
    render(error: "Could not create order: #{e.message}")
  end

  private

  def create_order(customer_id, product_ids)
    # Stub implementation
    SecureRandom.uuid
  end
end
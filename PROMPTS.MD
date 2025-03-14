# ActionMCP::Prompt

## Introduction

This document provides guidance on how to design and implement effective prompts for use with Large Language Models (LLMs) within the ActionMCP framework. Prompts are pre-defined templates that enable servers to define reusable LLM interactions, which clients can then surface to users. Well-designed prompts are crucial for ensuring that LLMs perform tasks accurately and efficiently.

## Prompt Engineering Principles

*   Clarity and Specificity
*   Context and Background
*   Constraints and Guidelines
*   Examples of good and bad prompts

## Prompt Structure in ActionMCP

*   `ActionMCP::Prompt` class
*   `prompt_name` and `description` methods
*   `argument` method for defining arguments
*   `call` method for prompt logic

## Dynamic Prompts

*   Accessing resources within prompts
*   Multi-step workflows

## Best Practices

*   Use clear, descriptive prompt names
*   Provide detailed descriptions for prompts and arguments
*   Validate all required arguments
*   Handle missing arguments gracefully
*   Consider versioning for prompt templates
*   Cache dynamic content when appropriate
*   Implement error handling
*   Document expected argument formats
*   Consider prompt composability
*   Test prompts with various inputs

## UI Integration

*   How prompts can be surfaced in client UIs (slash commands, quick actions, etc.)

## Security Considerations

*   Validating arguments
*   Sanitizing user input
*   Rate limiting
*   Access controls

## Examples

### Product Description Generator

This prompt generates product descriptions based on a product name and keywords.

```ruby
class ProductDescriptionPrompt < ActionMCP::Prompt
  description "Generate a product description"

  argument :product_name, description: "Name of the product", required: true
  argument :keywords, description: "Keywords related to the product", required: true

  def call
    render(text: "Write a compelling product description for #{product_name} using the following keywords: #{keywords}")
  end
end
```

### Customer Support Chatbot

This prompt helps a customer support chatbot answer questions about order status.

```ruby
class OrderStatusPrompt < ActionMCP::Prompt
  description "Answer questions about order status"

  argument :order_id, description: "The ID of the order", required: true
  argument :customer_name, description: "The name of the customer", required: false

  def call
    if customer_name
      render(text: "What is the status of order #{order_id} for customer #{customer_name}?")
    else
      render(text: "What is the status of order #{order_id}?")
    end
  end
end
```
# ActionMCP::Prompt

## Overview

ActionMCP::Prompt provides a framework for creating reusable prompt templates that can be used with LLMs. Each prompt
defines required and optional arguments, and generates messages that guide the LLM conversation with support for
multiple content types including text, images, audio, and resources.

## Core Components

### Prompt Definition

- Each prompt is a Ruby class inheriting from `ApplicationMCPPrompt`
- Required elements:
    - `description`: Explain what the prompt does
    - `argument`: Define expected inputs with descriptions, requirements, and possible constraints
    - `perform`: Core logic that executes the prompt's function

### Adding Content to Prompts

Use these methods to structure the prompt interaction with various content types:

#### Adding Messages via Render

- `render(text: "message")`: Add a user message with text content
- `render(text: "message", role: :assistant)`: Add an assistant message with text content
- `render(image: "base64_data", mime_type: "image/png")`: Add an image to the conversation
- `render(audio: "base64_data", mime_type: "audio/mpeg")`: Add audio content
- `render(resource: "file://path/to/resource", mime_type: "application/json", text: "{}")`: Add a resource with text
  content
- `render(resource: "file://path/to/resource", mime_type: "application/octet-stream", blob: "base64_data")`: Add a
  resource with binary content

#### Adding Messages Directly

```ruby
add_message(
  role: "user|assistant",
  content: {
    type: "text|image|audio|resource",
    text: "message", # For text type
    data: "base64_data", # For image/audio binary data
    mime_type: "image/png", # For non-text content
    resource: "uri", # For resource types
    blob: "base64_data" # For binary resource content
  }
)
```

## Usage Pattern

1. **Argument definition** happens through the `argument` method
2. **Prompt execution** occurs in the `perform` method
3. **Message construction** uses `render` or `add_message` to build conversation
4. **Multiple messages and content types** can be added to create a rich conversation flow

## Example Prompts

### Greeting Prompt with Text

```ruby

class GreetingPrompt < ApplicationMCPPrompt
  description "Generates a personalized greeting message"

  argument :name, description: "The name to greet", required: true
  argument :style, description: "Style of greeting", enum: %w[formal casual friendly], default: "friendly"

  def perform
    # Add messages directly
    render text: "Please create a greeting for #{name}"

    render role: "assistant",
           text: "I'd be happy to create a #{style} greeting for #{name}!"

    # Or use render and it will be added as a user message
    render text: "The greeting should be in #{style} style."
  end
end
```

### Product Demo Prompt with Mixed Content

```ruby

class ProductDemoPrompt < ApplicationMCPPrompt
  description "Creates a product demonstration with visual aids"

  argument :product_name, description: "Name of the product", required: true
  argument :include_specs, description: "Whether to include technical specifications", required: false, default: true

  def perform
    # Add initial user request
    render text: "I need a demonstration of the #{product_name}"

    # Add product image
    render(
      image: product_image_base64(product_name),
      mime_type: "image/png",
      role: :assistant
    )

    # Add assistant response with text
    render(
      text: "Here's the #{product_name}. It's our latest innovation.",
      role: :assistant
    )

    # Conditionally add technical specifications document
    if include_specs
      render(
        resource: "file://product/specs/#{product_name.downcase.gsub(' ', '_')}.pdf",
        mime_type: "application/pdf",
        blob: get_product_specs_pdf(product_name),
        role: :assistant
      )

      render(
        text: "I've included the technical specifications for your reference.",
        role: :assistant
      )
    end
  end

  private

  def product_image_base64(product_name)
    # Implementation to retrieve product image as base64
  end

  def get_product_specs_pdf(product_name)
    # Implementation to retrieve product specs as base64 PDF
  end
end
```

## Key Implementation Notes

1. Use `argument` method to define input parameters with appropriate constraints
2. Create natural conversation flows with multiple messages and content types
3. Use conditional logic to adapt prompts based on arguments
4. Set default values for optional arguments
5. Include descriptive argument definitions to guide parameter usage
6. Mix different content types (text, images, audio, resources) for richer interactions
7. Consider using enums (`enum: %w[option1 option2]`) to constrain input values
8. Use ActiveModel validations for input verification
9. Use appropriate MIME types when including non-text content
10. Structure multi-turn conversations with alternating user and assistant messages

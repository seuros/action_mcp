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

### Callbacks

ActionMCP::Prompt supports callbacks that run around the `perform` method, allowing you to:
- Validate or transform arguments before processing
- Perform pre-processing actions before the main logic executes
- Handle post-processing of results after the main logic completes
- Check for malicious input or implement security measures
- Add logging or instrumentation around prompt execution

These callbacks provide powerful hooks to extend and customize prompt behavior without modifying the core logic.

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
2. **Callback registration** can be added to extend the prompt's behavior
3. **Prompt execution** occurs in the `perform` method
4. **Message construction** uses `render` or `add_message` to build conversation
5. **Multiple messages and content types** can be added to create a rich conversation flow

## Example Prompts

### Greeting Prompt with Text

```ruby
class GreetingPrompt < ApplicationMCPPrompt
  description "Generates a personalized greeting message"

  argument :name, description: "The name to greet", required: true
  argument :style, description: "Style of greeting", enum: %w[formal casual friendly], default: "friendly"

  # Before callback to sanitize input
  before_perform do
    self.name = name.strip.capitalize
  end

  def perform
    # Add messages directly
    render text: "Please create a greeting for #{name}"

    render role: "assistant",
           text: "I'd be happy to create a #{style} greeting for #{name}!"

    # Or use render and it will be added as a user message
    render text: "The greeting should be in #{style} style."
  end
  
  # After callback for logging or additional processing
  after_perform do |result|
    Rails.logger.info("Generated greeting for #{name} in #{style} style")
  end
end
```

### Product Demo Prompt with Mixed Content

```ruby
class ProductDemoPrompt < ApplicationMCPPrompt
  description "Creates a product demonstration with visual aids"

  argument :product_name, description: "Name of the product", required: true
  argument :include_specs, description: "Whether to include technical specifications", required: false, default: true

  # Before callback to verify product exists
  before_perform do
    raise ArgumentError, "Product not found" unless product_exists?(product_name)
  end

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

  # After callback to track usage
  after_perform do |result|
    Analytics.track_product_demo(product_name, include_specs)
  end

  private

  def product_exists?(product_name)
    # Implementation to check if product exists
  end

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
2. Register callbacks with `before_perform` and `after_perform` to extend prompt behavior
3. Use callbacks for input validation, sanitization, logging, and analytics
4. Create natural conversation flows with multiple messages and content types
5. Use conditional logic to adapt prompts based on arguments
6. Set default values for optional arguments
7. Include descriptive argument definitions to guide parameter usage
8. Mix different content types (text, images, audio, resources) for richer interactions
9. Consider using enums (`enum: %w[option1 option2]`) to constrain input values
10. Use ActiveModel validations for input verification
11. Use appropriate MIME types when including non-text content
12. Structure multi-turn conversations with alternating user and assistant messages
13. Callbacks can be used to mutate arguments, check for malicious input, or perform additional processing before and after the main prompt execution.

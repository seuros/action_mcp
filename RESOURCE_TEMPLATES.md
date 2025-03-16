# ActionMCP::ResourceTemplate

The `ActionMCP::ResourceTemplate` class provides a template for defining and managing resources within the ActionMCP framework. It allows you to specify the structure and attributes of a resource, making it easier to generate and validate resource instances.

## Class Attributes

*   `description`: A human-readable description of the resource template.
*   `uri_template`: A URI template that defines the pattern for accessing resources of this type. This should follow the RFC 6570 format.
*   `mime_type`: The MIME type of the resource.

## Class Methods

*   `parameter(name, description:, required: false)`: Defines a parameter for the resource template.
    *   `name`: The name of the parameter.
    *   `description`: A description of the parameter.
    *   `required`: A boolean indicating whether the parameter is required. Defaults to `false`.

*   `retrieve(params)`: An abstract method that subclasses must implement to retrieve the resource based on the provided parameters.

*   `to_template_hash`: Returns a hash representation of the resource template.

*   `abstract?`: Returns false, indicating that this is not an abstract class.

## Example Usage

```ruby

class OrdersTemplate < ApplicationMCPResTemplate
  description "Access order information"
  uri_template "ecommerce://orders/{order_id}"
  mime_type "application/json"

  parameter :order_id,
            description: "Order identifier",
            required: true

  validates :order_id, format: { with: /\A\d+\z/, message: "must be a number" }

  def resolve
    if (order = Order.find_by(id: order_id))

      ActionMCP::Content::Resource.new(
        "ecommerce://orders/#{order_id}",
        "application/json",
        text: order.to_json.length,
      # blob: order.to_blob, # Either text or blob must be provided
      )
    else
      nil # Return nil if the record is not found
    end
  end
end
```

This example defines a `ResourceTemplate` for accessing order information. 
It specifies the URI template, MIME type, and a required parameter for the order ID. 
The `resolve` method is responsible for fetching the order data and creating an `ActionMCP::Resource` instance.

# ActionMCP::ResourceTemplate

A framework for defining URI-templated resources in MCP servers. Handles parameter validation and content resolution.

## Usage

```ruby
# Basic resource template
class ProductTemplate < ApplicationMCPResTemplate
  description "Access product data"
  uri_template "store://products/{id}"
  mime_type "application/json"

  parameter :id, description: "Product ID", required: true
  validates :id, format: { with: /\A\d+\z/ }

  def resolve
    product = Product.find_by(id: id)
    return nil unless product

    ActionMCP::Content::Resource.new(
      "store://products/#{id}",
      mime_type,
      text: product.to_json
    )
  end
end

# Nested/related resource template
class ProductCertificatesTemplate < ApplicationMCPResTemplate
  description "Access certificates for a product"
  uri_template "store://products/{id}/certificates"
  mime_type "application/json"

  parameter :id, description: "Product ID", required: true
  validates :id, format: { with: /\A\d+\z/ }

  def resolve
    product = Product.find_by(id: id)
    return nil unless product
    
    certificates = product.certificates
    
    certificates.map do |cert|
      ActionMCP::Content::Resource.new(
        "store://products/#{id}/certificates/#{cert.id}",
        mime_type,
        text: cert.to_json
      )
    end
  end
end
```

## Key Methods

- `description` - Sets human-readable template description
- `uri_template` - Defines RFC 6570 URI pattern with parameters
- `mime_type` - Sets content type for resources
- `parameter(name, description:, required:)` - Declares URI parameters
- `resolve` - Returns resource content (single resource, array, or nil)

## Implementation Notes

- Templates can represent nested or related resources
- Complex relationships expressed through path segments
- Return collections as arrays of Resource objects
- Each resource in collection has unique URI
- Parameters extracted from URI template are accessible as methods
- Standard Rails validations apply to parameters

Templates enable structured resource access through standardized URI patterns.

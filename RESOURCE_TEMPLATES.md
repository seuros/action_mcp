# ActionMCP::ResourceTemplate

A framework for defining URI-templated resources in MCP servers. Handles parameter validation, content resolution, and static resource listing.

> **Client compatibility note:** Not all MCP clients support both resource endpoints. Claude Code (as of v2.1.50) only calls `resources/list` (not `resources/templates/list`), and Codex stubs resource methods entirely. If your resources should be visible across clients, you **must** implement `self.list` on your templates. Crush and VS Code support both endpoints.

## Usage

### Basic Template with resolve

```ruby
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
```

### Static Resource Listing

Templates can enumerate concrete resources for `resources/list` by overriding `self.list`:

```ruby
class ProductTemplate < ApplicationMCPResTemplate
  description "Access product data"
  uri_template "store://products/{id}"
  mime_type "application/json"

  parameter :id, description: "Product ID", required: true

  # Enumerate concrete resources for resources/list
  def self.list(session: nil)
    Product.limit(100).map do |product|
      build_resource(
        uri: "store://products/#{product.id}",
        name: product.name,
        title: "Product ##{product.id}",
        description: "Product: #{product.name}",
        size: product.data.bytesize
      )
    end
  end

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
```

### Nested/Related Resource Template

```ruby
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

### Class Methods

- `description` - Sets human-readable template description
- `uri_template` - Defines RFC 6570 URI pattern with parameters
- `mime_type` - Sets content type for resources
- `parameter(name, description:, required:)` - Declares URI parameters
- `list(session:)` - Override to enumerate concrete resources for `resources/list`
- `lists_resources?` - Returns true if `list` is overridden
- `build_resource(uri:, name:, **opts)` - Factory helper that inherits template defaults
- `readable_uri?(uri)` - Check if a URI matches and validates against this template

### Instance Methods

- `resolve` - Returns resource content (single resource, array, or nil)

## Static Resources (`resources/list`)

The MCP spec defines two resource surfaces:

- **`resources/list`** — concrete resources with known URIs
- **`resources/templates/list`** — parameterized URI patterns

Override `self.list(session:)` to expose concrete resources. Each listed URI must be readable by the same template (validated via `readable_uri?`).

### `build_resource` Helper

`build_resource` creates `ActionMCP::Resource` instances with template defaults:

```ruby
def self.list(session: nil)
  [
    build_resource(uri: "store://products/1", name: "Widget"),
    build_resource(uri: "store://products/2", name: "Gadget", title: "The Gadget")
  ]
end
```

Fields `description` and `mime_type` fall back to the template's values if not provided.

### Deduplication and Collision Rules

- Resources are deduplicated by URI across all templates
- If two templates list the same URI with identical metadata, the duplicate is silently dropped
- If two templates list the same URI with different metadata, a JSON-RPC error is returned

### Cursor Pagination

Both `resources/list` and `resources/templates/list` support cursor-based pagination:

```json
{"jsonrpc":"2.0","id":1,"method":"resources/list","params":{"cursor":"MTA="}}
```

The response includes `nextCursor` when more results are available.

## Read Contract (`resources/read`)

`resolve` should return `ActionMCP::Content::Resource` for MCP-compliant read output:

```ruby
def resolve
  ActionMCP::Content::Resource.new(uri, mime_type, text: data.to_json)
end
```

The response shape is:

```json
{
  "contents": [
    { "uri": "store://products/1", "mimeType": "application/json", "text": "{...}" }
  ]
}
```

For binary resources, use `blob:` instead of `text:`:

```ruby
ActionMCP::Content::Resource.new(uri, "image/png", blob: Base64.strict_encode64(image_data))
```

## Implementation Notes

- Templates can represent nested or related resources
- Complex relationships expressed through path segments
- Return collections as arrays of Resource objects
- Each resource in collection has unique URI
- Parameters extracted from URI template are accessible as methods
- Standard Rails validations apply to parameters
- Listed URIs are validated against the declaring template's pattern

## Callbacks

Resource templates support callbacks around the `resolve` method:

- `before_resolve` - Called before `resolve`
- `after_resolve` - Called after `resolve`
- `around_resolve` - Wraps `resolve` execution

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

All list endpoints (`resources/list`, `resources/templates/list`, `tools/list`, `prompts/list`) support cursor-based pagination per the MCP specification.

Pagination is **opt-in** — set `pagination_page_size` in your configuration to enable it:

```ruby
config.action_mcp.pagination_page_size = 10
```

When enabled, responses include a `nextCursor` when more results are available. Clients should pass this cursor back to fetch the next page:

```json
{"jsonrpc":"2.0","id":1,"method":"resources/list","params":{"cursor":"MTA"}}
```

When `pagination_page_size` is `nil` (the default), all items are returned in a single response. Enable only when your clients support cursor-based pagination.

Tasks (`tasks/list`) always paginate regardless of this setting since they are database-backed and can grow unbounded.

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

## Testing

ActionMCP provides test helpers for resource templates. Include `ActionMCP::TestHelper` in your test class:

```ruby
require "test_helper"
require "action_mcp/test_helper"

class ProductTemplateTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "template is registered" do
    assert_mcp_resource_template_findable("products")
  end

  test "resolves a product by URI" do
    resp = resolve_mcp_resource("store://products/1")

    assert resp.success?
    assert_not_empty resp.contents
    assert_equal "application/json", resp.contents.first.mime_type
  end

  test "returns error for nonexistent product" do
    resp = resolve_mcp_resource_with_error("store://products/0")

    assert resp.is_error
  end

  test "lists available resources" do
    resources = ProductTemplate.list
    assert_kind_of Array, resources
  end
end
```

Available helpers:

- `assert_mcp_resource_template_findable(name)` - Verifies a resource template is registered
- `resolve_mcp_resource(uri)` - Resolves a URI via the matching template and asserts success
- `resolve_mcp_resource_with_error(uri)` - Resolves a URI without asserting success (for testing error cases)

## Callbacks

Resource templates support callbacks around the `resolve` method:

- `before_resolve` - Called before `resolve`
- `after_resolve` - Called after `resolve`
- `around_resolve` - Wraps `resolve` execution

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

## MCP Apps (UI Resources)

Resource templates can serve interactive HTML UIs under the MCP Apps extension (`io.modelcontextprotocol/ui`, SEP-1865). The host renders the HTML in a sandboxed iframe and communicates with it via JSON-RPC over `postMessage`. See the Hitchhiker's Guide for the narrative; this section is the reference.

### MIME Type Shorthand

The spec MIME is `text/html;profile=mcp-app`. The `:mcp_app` symbol resolves to that string through `ActionMCP::MimeTypes`, which is engine-owned (no global `Mime::Type.register` pollution):

```ruby
mime_type :mcp_app                          # resolves to "text/html;profile=mcp-app"
mime_type "text/html;profile=mcp-app"       # equivalent, explicit
mime_type ActionMCP::MimeTypes::APP_HTML    # equivalent, constant
```

Unknown symbols fall back to `Mime[]` (the app's own registered formats), and raise `KeyError` if nothing matches.

### The `ui` Class Macro

`ui(**data)` declares the `_meta.ui` block emitted on every `resources/read` response for this template. The keys are spec-defined and stored verbatim (camelCase per the wire format):

```ruby
class WeatherDashboardTemplate < ApplicationMCPResTemplate
  uri_template "ui://weather/dashboard"
  mime_type :mcp_app

  ui csp: { connectDomains: %w[https://api.openweathermap.org],
            resourceDomains: %w[https://cdn.jsdelivr.net] },
     permissions: { clipboardWrite: {} },
     prefersBorder: true,
     domain: "a904794854a047f6.claudemcpcontent.com"

  def resolve
    render_ui(template: "mcp/ui/weather_dashboard")
  end
end
```

Recognized keys:

- **`csp`** — `{ connectDomains:, resourceDomains:, frameDomains:, baseUriDomains: }`. Each is an array of **origins** (scheme + host, optionally wildcard subdomain): `https://api.example.com`, `wss://stream.example.com`, `https://*.cloudflare.com`. This is a strict subset of CSP source expressions — no `'self'`, `'unsafe-inline'`, `data:`, nonces, or hashes; the host adds its own implicit sources. Bare hostnames are not valid. Per-directive defaults when omitted or `[]`: `connectDomains` → no external network, `resourceDomains` → no external scripts/images/styles/fonts, `frameDomains` → `frame-src 'none'`, `baseUriDomains` → `base-uri 'self'`. If the entire `csp` key is omitted, the host applies a fully restrictive default CSP (essentially `'self' + 'unsafe-inline'` for inline scripts/styles, `connect-src 'none'`). Note: this is **not** the same as Rails' `Content-Security-Policy` HTTP header — Rails CSP applies to responses your app serves; MCP CSP is JSON metadata the host uses to construct the iframe's CSP.
- **`permissions`** — `{ camera: {}, microphone: {}, geolocation: {}, clipboardWrite: {} }`. Requests Permission Policy features for the inner iframe; hosts MAY honor these via the iframe `allow` attribute. `clipboardWrite` maps specifically to `clipboard-write`. Apps SHOULD feature-detect and handle denial — never assume a permission was granted.
- **`prefersBorder`** — boolean. `true` requests host-rendered border + background; `false` requests none; omitted means host decides. The spec recommends setting this explicitly since host defaults vary.
- **`domain`** — string. Optional dedicated sandbox origin for the View. **Host-dependent format** — common patterns include hash-based subdomains (Claude: `{hash}.claudemcpcontent.com`) or URL-derived subdomains (ChatGPT: `www-example-com.oaiusercontent.com`). Consult host-specific documentation; do not copy example domains. If omitted, the host uses its default sandbox origin (typically per-conversation). Set this when you need a stable origin for OAuth callbacks, CORS allowlists, or API key origin checks.

Successive `ui(**)` calls merge via `deep_merge`, so you can split declarations or have a base template define CSP and a subclass add `prefersBorder`.

**Origin validation at class load.** The `ui` macro validates every `csp.*Domains` entry as an `http(s)://` origin and raises `ArgumentError` immediately for bare hostnames or unsupported schemes (e.g., `wss://`, `ftp://`). Wildcard subdomains (`https://*.cloudflare.com`), ports, and paths are accepted. Validation happens at class declaration time so misconfigured templates fail at file load — not on the first `resources/read` call.

#### Metadata Location: `resources/list` vs `resources/read`

The spec allows `_meta.ui` on both the `resources/list` entry (static default reviewable at connection time) and the `resources/read` content item (per-response, possibly dynamic). When both are present, **the content-item value takes precedence**, and hosts MUST check both locations.

ActionMCP emits `_meta.ui` on the `resources/read` content via `render_ui` — the spec's recommended location for dynamic or per-response metadata. The class-level `meta(...)` macro (distinct from `ui(...)`) feeds the `resources/list` entry's `_meta`, which is where you'd put static defaults if you want hosts to review security configuration without fetching the resource.

### The `render_ui` Instance Helper

`render_ui` builds the `ActionMCP::Content::Resource` for you, pulling in the class-level `ui` metadata, the template's `uri_template`, and the resolved `mime_type`. Two source modes:

```ruby
# From a Rails view (preferred — ERB interpolation, view paths, partials all work)
def resolve
  render_ui(template: "mcp/ui/weather_dashboard")
end

# From an inline string (useful for trivial UIs or runtime-generated HTML)
def resolve
  render_ui(text: "<!doctype html><html>...</html>")
end
```

Full signature:

```ruby
render_ui(text: nil, template: nil, layout: false, locals: {})
```

- **`text:`** — raw HTML string. Mutually exclusive with `template:`.
- **`template:`** — Rails view path. Rendered via `ApplicationController.render` so all your view paths, helpers, and layouts are available.
- **`layout:`** — defaults to `false` (no layout). Pass a layout name to wrap the view.
- **`locals:`** — passed through to the renderer.

Raises `ArgumentError` if neither `:text` nor `:template` is supplied.

### Where the HTML Lives

Rails views by convention. For a template that calls `render_ui(template: "mcp/ui/weather_dashboard")`, the file is at `app/views/mcp/ui/weather_dashboard.html.erb`. Standard ERB rules apply: helpers, partials, locals, layouts.

```erb
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Weather</title>
</head>
<body data-locale="<%= I18n.locale %>">
  <div class="card" id="weather"></div>
  <script>
    // The View acts as an MCP client over postMessage.
    // Send ui/initialize, wait for hostContext, then consume tool results.
  </script>
</body>
</html>
```

The host MUST NOT push tool results until the View sends `ui/notifications/initialized`. Pages that skip the handshake render but never receive data.

### Linking from Tools

A Tool declares which UI to render with its result via `renders_ui`:

```ruby
class WeatherTool < ApplicationMCPTool
  tool_name "weather"
  renders_ui "ui://weather/dashboard"
  # Optionally restrict visibility:
  # renders_ui "ui://weather/dashboard", visibility: %i[model app]

  property :location, type: "string", required: true

  def perform
    render structured: {
      current: { temperature: 22.5, condition: "Sunny", humidity: 65 },
      metadata: { location_found: location }
    }
  end
end
```

`renders_ui` emits `_meta.ui.resourceUri` (and optionally `_meta.ui.visibility`) on `tools/list`. The deprecated flat `_meta["ui/resourceUri"]` form is never emitted.

**No fallback branches (ActionMCP convention).** The spec says servers SHOULD provide text-only fallback behavior; ActionMCP is more opinionated and skips it. Tools always emit their structured response; clients are expected to consume structured output. Hosts that don't support the extension see the same payload and ignore the `_meta.ui` metadata.

### Wire Format Reference

What `resources/read` returns for the WeatherDashboardTemplate above:

```json
{
  "contents": [
    {
      "uri": "ui://weather/dashboard",
      "mimeType": "text/html;profile=mcp-app",
      "text": "<!doctype html>...</html>",
      "_meta": {
        "ui": {
          "csp": {
            "connectDomains": ["https://api.openweathermap.org"],
            "resourceDomains": ["https://cdn.jsdelivr.net"]
          },
          "permissions": { "clipboardWrite": {} },
          "prefersBorder": true,
          "domain": "a904794854a047f6.claudemcpcontent.com"
        }
      }
    }
  ]
}
```

And what `tools/list` returns for the linked tool:

```json
{
  "name": "weather",
  "description": "...",
  "inputSchema": { "type": "object", ... },
  "_meta": {
    "ui": { "resourceUri": "ui://weather/dashboard" }
  }
}
```

### Capability Introspection

`Capability#client_supports_ui?` returns `true` when the connected client advertised `io.modelcontextprotocol/ui` in `capabilities.extensions` during `initialize`. It's available on every Tool, Prompt, and ResourceTemplate instance for observability and metrics; ActionMCP does not branch response content off it.

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

# OAuth 2.1 Authentication in ActionMCP

ActionMCP provides comprehensive OAuth 2.1 authentication support for secure API access. This document covers configuration, usage, and implementation details.

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
- [Authentication Methods](#authentication-methods)
- [OAuth Server Setup](#oauth-server-setup)
- [Client Integration](#client-integration)
- [Security Features](#security-features)
- [Error Handling](#error-handling)
- [Development and Testing](#development-and-testing)
- [Migration from JWT](#migration-from-jwt)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Overview

ActionMCP's OAuth 2.1 implementation is built on [Omniauth](https://github.com/omniauth/omniauth) and provides:

- **OAuth 2.1 compliance** with PKCE (Proof Key for Code Exchange) support
- **Multiple authentication methods** (`none`, `jwt`, `oauth`) with configurable fallback
- **Bearer token validation** with proper error responses
- **Flexible configuration** via `config/mcp.yml`
- **Automatic middleware integration** - OAuth middleware is injected automatically when configured

## Configuration

### Basic Configuration

Configure authentication in your `config/mcp.yml` file:

```yaml
# config/mcp.yml
development:
  # No authentication for development
  authentication: ["none"]
  
  profiles:
    primary:
      tools: ["all"]
      prompts: ["all"]
      resources: ["all"]

test:
  # JWT authentication for testing  
  authentication: ["jwt"]
  
  profiles:
    primary:
      tools: ["all"]
      prompts: ["all"]
      resources: ["all"]

production:
  # OAuth preferred, JWT fallback
  authentication: ["oauth", "jwt"]
  
  # OAuth configuration
  oauth:
    provider: "application_oauth_provider"
    client_id: "<%= ENV['OAUTH_CLIENT_ID'] %>"
    client_secret: "<%= ENV['OAUTH_CLIENT_SECRET'] %>"
    issuer_url: "<%= ENV['OAUTH_ISSUER_URL'] %>"
    scopes_supported: ["mcp:tools", "mcp:resources", "mcp:prompts"]
    enable_dynamic_registration: true
    enable_token_revocation: true
    pkce_required: true
    
  profiles:
    primary:
      tools: ["all"]
      prompts: ["all"]
      resources: ["all"]
      
    external_clients:
      tools: ["WeatherForecastTool"]
      prompts: []
      resources: []
```

### OAuth Configuration Options

| Option | Description | Required |
|--------|-------------|----------|
| `provider` | OAuth provider class name | Yes |
| `client_id` | OAuth client identifier | Yes* |
| `client_secret` | OAuth client secret | Yes* |
| `issuer_url` | OAuth authorization server URL | Yes |
| `scopes_supported` | Array of supported OAuth scopes | No |
| `enable_dynamic_registration` | Enable RFC 7591 dynamic client registration | No |
| `enable_token_revocation` | Enable RFC 7009 token revocation | No |
| `pkce_required` | Require PKCE for all flows (recommended) | No |
| `userinfo_endpoint` | Custom userinfo endpoint URL | No |
| `introspection_endpoint` | Custom token introspection endpoint URL | No |

*Required for server-side flows, optional for dynamic registration

## Authentication Methods

ActionMCP supports multiple authentication methods that can be combined:

### `none` - No Authentication
```yaml
authentication: ["none"]
```
- Suitable for development environments
- Creates a default development user
- **Never use in production**

### `jwt` - JWT Token Authentication  
```yaml
authentication: ["jwt"]
```
- Uses signed JWT tokens
- Backward compatible with existing implementations
- Good for internal services

### `oauth` - OAuth 2.1 Authentication
```yaml
authentication: ["oauth"]
```
- Full OAuth 2.1 compliance with PKCE
- Bearer token validation
- Suitable for external clients

### Combined Authentication
```yaml
authentication: ["oauth", "jwt"]
```
- Tries OAuth first, falls back to JWT
- Smooth migration path
- Flexible client support

## OAuth Server Setup

### 1. Create OAuth Provider

Create a custom OAuth provider class:

```ruby
# app/oauth/application_oauth_provider.rb
class ApplicationOAuthProvider
  def self.authorize(client, params, request)
    # Implement authorization logic
    # Redirect to authorization page or auto-approve
  end
  
  def self.exchange_authorization_code(client, code, verifier, redirect_uri)
    # Exchange authorization code for access token
    # Verify PKCE code_verifier
    # Return token response
  end
  
  def self.verify_access_token(token)
    # Validate access token
    # Return token info with user details
    {
      "active" => true,
      "sub" => "user_123",
      "scope" => "mcp:tools mcp:resources",
      "exp" => 1.hour.from_now.to_i
    }
  end
  
  def self.revoke_token(client, token)
    # Revoke access or refresh token
  end
end
```

### 2. Update Application Gateway

Ensure your gateway supports OAuth user resolution:

```ruby
# app/mcp/gateways/application_gateway.rb
class ApplicationGateway < ActionMCP::Gateway
  protected
  
  def resolve_user_from_oauth(token_info)
    return nil unless token_info.is_a?(Hash)
    
    user_id = token_info["sub"] || token_info["user_id"]
    return nil unless user_id
    
    # Find user by OAuth subject or ID
    user = User.find_by(oauth_subject: user_id) || User.find_by(id: user_id)
    return nil unless user

    { user: user }
  end
end
```

### 3. Database Schema

Add OAuth support to your User model:

```ruby
# Add to User migration
add_column :users, :oauth_subject, :string
add_index :users, :oauth_subject, unique: true
```

## Client Integration

### Using Bearer Tokens

Clients authenticate by including a Bearer token in the Authorization header:

```bash
curl -H "Authorization: Bearer <access_token>" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' \
     http://localhost:3000/mcp
```

### OAuth Authorization Flow

1. **Client Registration** (if dynamic registration enabled)
2. **Authorization Request** with PKCE challenge
3. **User Authorization** 
4. **Authorization Code Exchange** with PKCE verifier
5. **API Access** with Bearer token
6. **Token Refresh** (if refresh tokens issued)

## Security Features

### PKCE (Proof Key for Code Exchange)

ActionMCP enforces PKCE for enhanced security:

```ruby
# PKCE is automatically handled by the Omniauth strategy
# Code challenge and verifier are generated and verified
```

### Token Validation

Tokens are validated on every request:

```ruby
# Automatic validation via OAuth middleware
# Invalid tokens receive proper OAuth error responses
```

### Standard Error Responses

OAuth errors follow RFC 6749 specifications:

```json
{
  "error": "invalid_token",
  "error_description": "The access token provided is expired, revoked, malformed, or invalid"
}
```

## Error Handling

### HTTP Status Codes

| Status | Error | Description |
|--------|-------|-------------|
| 401 | `invalid_token` | Invalid or expired token |
| 403 | `insufficient_scope` | Token lacks required scope |
| 400 | `invalid_request` | Malformed request |
| 500 | `server_error` | Internal server error |

### WWW-Authenticate Headers

401/403 responses include proper WWW-Authenticate headers:

```
WWW-Authenticate: Bearer realm="MCP API", error="invalid_token"
WWW-Authenticate: Bearer realm="MCP API", error="insufficient_scope", scope="mcp:tools"
```

## Development and Testing

### Development Mode

Use `authentication: ["none"]` for frictionless development:

```yaml
development:
  authentication: ["none"]
```

### Testing with JWT

Use JWT tokens for predictable testing:

```yaml
test:
  authentication: ["jwt"]
```

Generate test tokens:

```ruby
# In tests
token = JWT.encode({ user_id: user.id }, ActionMCP::JwtDecoder.secret, ActionMCP::JwtDecoder.algorithm)
get "/mcp", headers: { "Authorization" => "Bearer #{token}" }
```

### OAuth Testing

Mock OAuth validation for integration tests:

```ruby
# Test helper
def mock_oauth_token(user, scopes = ["mcp:tools"])
  request.env["action_mcp.oauth_token_info"] = {
    "active" => true,
    "sub" => user.id.to_s,
    "scope" => scopes.join(" ")
  }
end
```

## Migration from JWT

### Step 1: Add OAuth Configuration

```yaml
production:
  authentication: ["jwt", "oauth"]  # JWT first for compatibility
  oauth:
    # Add OAuth config
```

### Step 2: Deploy with Dual Support

Both JWT and OAuth tokens work simultaneously.

### Step 3: Migrate Clients

Update clients to use OAuth tokens progressively.

### Step 4: Switch Priority

```yaml
production:
  authentication: ["oauth", "jwt"]  # OAuth first
```

### Step 5: Remove JWT (Optional)

```yaml
production:
  authentication: ["oauth"]  # OAuth only
```

## Advanced Usage

### Custom Scopes

Define application-specific OAuth scopes:

```yaml
oauth:
  scopes_supported: 
    - "mcp:tools:read"
    - "mcp:tools:execute" 
    - "mcp:resources:read"
    - "mcp:prompts:read"
```

Validate scopes in your provider:

```ruby
def self.verify_access_token(token)
  # Validate token and return scope information
  {
    "active" => true,
    "sub" => "user_123",
    "scope" => "mcp:tools:read mcp:resources:read"
  }
end
```

### Profile-Based Access Control

Different profiles can expose different capabilities while using the same global authentication:

```yaml
authentication: ["oauth"]  # Global authentication requirement

profiles:
  admin:
    tools: ["all"]
    prompts: ["all"] 
    resources: ["all"]
    
  public:
    tools: ["WeatherTool"]
    prompts: []
    resources: []
```

### Multiple OAuth Providers

Support multiple OAuth providers:

```ruby
# Use different providers based on client_id or issuer
class MultiOAuthProvider
  def self.verify_access_token(token)
    provider = detect_provider(token)
    provider.verify_access_token(token)
  end
  
  private
  
  def self.detect_provider(token)
    # Logic to determine provider based on token
  end
end
```

## Troubleshooting

### Common Issues

1. **"No valid authentication found"**
   - Check `config/mcp.yml` authentication configuration
   - Verify OAuth provider is properly configured
   - Ensure Bearer token is included in request

2. **"Invalid token" errors**
   - Verify OAuth provider's `verify_access_token` implementation
   - Check token format and expiration
   - Confirm OAuth server is accessible

3. **"undefined method 'any?' for nil" in logs**
   - This is expected when testing token validation against non-existent OAuth servers
   - Indicates OAuth strategy is attempting validation correctly

### Debugging

Enable detailed OAuth logging:

```ruby
# In development.rb
config.log_level = :debug

# OAuth strategy includes detailed error logging
```

Check OAuth middleware processing:

```ruby
# Add to application.rb for debugging
config.middleware.insert_before ActionMCP::OAuth::Middleware, lambda { |env|
  Rails.logger.debug "Request path: #{env['PATH_INFO']}"
  Rails.logger.debug "Auth header: #{env['HTTP_AUTHORIZATION']}"
}
```

### Testing OAuth Server Connectivity

```bash
# Test OAuth server metadata endpoint
curl https://your-oauth-server/.well-known/oauth-authorization-server

# Test token introspection
curl -X POST https://your-oauth-server/oauth/introspect \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "token=<access_token>"
```

---

For additional support, please refer to the [ActionMCP documentation](README.md) or [file an issue](https://github.com/seuros/action_mcp/issues).
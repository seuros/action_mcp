# OAuth 2.1 Authentication in ActionMCP

ActionMCP provides comprehensive OAuth 2.1 authentication support for secure API access. This document covers configuration, usage, and implementation details.

## Table of Contents

- [Quick Start Guide](#quick-start-guide)
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

## Quick Start Guide

This guide will help you quickly set up OAuth authentication for your ActionMCP server with your editor.

### Prerequisites

The server should be configured for OAuth in development mode:
- OAuth authentication is enabled: `authentication: ["oauth"]`
- Dynamic client registration is enabled
- Public clients are allowed (no client_secret required)
- PKCE is optional for development

### Step 1: Editor Configuration

Update your MCP configuration file (`.mcp.json` or equivalent):

```json
{
  "mcpServers": {
    "action_mcp": {
      "type": "http",
      "url": "http://localhost:62770",
      "auth": {
        "type": "oauth",
        "authorization_url": "http://localhost:62770/oauth/authorize",
        "token_url": "http://localhost:62770/oauth/token",
        "scopes": ["mcp:tools", "mcp:resources", "mcp:prompts"],
        "pkce": true
      }
    }
  }
}
```

**Note:** Your editor will handle:
- Dynamic client registration (no need to pre-register a client)
- Dynamic redirect URI (editors use random ports)
- PKCE flow
- Token storage

### Step 2: Start the Server

```bash
bundle exec rails s -c mcp.ru -p 62770
```

### Step 3: Connect

1. **Restart your editor** to pick up the new configuration
2. **Connect to the MCP server** - Your editor will:
   - Automatically register as a new OAuth client
   - Open your browser for authorization
   - Complete the OAuth flow

### Step 4: Development Auto-Approval

In development mode, the server is configured to auto-approve OAuth clients, so you won't see a consent page. The flow will complete automatically.

### Verification

You can verify the OAuth endpoints are working:

```bash
# Authorization server metadata
curl http://localhost:62770/.well-known/oauth-authorization-server

# Protected resource metadata
curl http://localhost:62770/.well-known/oauth-protected-resource
```

### Common Issues

1. **"OAuth account information not found in config" error:**
   - Ensure the server has OAuth enabled: `authentication: ["oauth"]`
   - Check that OAuth configuration is in the correct environment section

2. **Browser doesn't open:**
   - Check if you're in an SSH session (OAuth requires local browser access)
   - Try manually opening the authorization URL

3. **401 Unauthorized errors:**
   - Verify OAuth is enabled in the server configuration
   - Check the server logs for specific authentication errors

For more detailed configuration options, see the sections below.

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

### Option 1: Built-in OAuth Provider (Recommended for New Projects)

ActionMCP includes a built-in OAuth provider for quick setup:

1. **Generate OAuth setup**:
   ```bash
   bundle exec rails generate action_mcp:oauth_setup
   bundle exec rails db:migrate
   ```

2. **Configure in `config/mcp.yml`**:
   ```yaml
   development:
     authentication: ["oauth"]
     gateway_class: "ApplicationGateway"
     oauth:
       issuer: "http://localhost:62770"
       authorization_endpoint: "http://localhost:62770/oauth/authorize"
       token_endpoint: "http://localhost:62770/oauth/token"
       registration_endpoint: "http://localhost:62770/oauth/register"
       pkce_supported: true
       scopes_supported: ["mcp:tools", "mcp:resources", "mcp:prompts"]
   ```

3. **Start the standalone MCP server**:
   ```bash
   # ActionMCP runs as a standalone server via mcp.ru
   cd test/dummy && bin/rails s -c mcp.ru -p 62770

   # Or with Falcon (recommended for production)
   cd test/dummy && bundle exec falcon serve --bind http://0.0.0.0:62770 mcp.ru
   ```

   **Note**: ActionMCP is designed to run as a standalone server process, not mounted within your main Rails application. This prevents blocking issues with persistent SSE connections and provides better scalability.

### Option 2: External OAuth Provider Integration

If you have an existing OAuth 2.1 provider (Ory, Auth0, Keycloak, etc.), you can integrate it with ActionMCP:

1. **Configure your OAuth provider endpoints**:
   ```yaml
   production:
     authentication: ["oauth"]
     gateway_class: "ExternalOAuthGateway"
     oauth:
       issuer: "https://your-oauth-provider.example.com"
       authorization_endpoint: "https://your-oauth-provider.example.com/oauth2/auth"
       token_endpoint: "https://your-oauth-provider.example.com/oauth2/token"
       registration_endpoint: "https://your-oauth-provider.example.com/oauth2/register"
       introspection_endpoint: "https://your-oauth-provider.example.com/oauth2/introspect"
       userinfo_endpoint: "https://your-oauth-provider.example.com/userinfo"
       pkce_supported: true
       scopes_supported: ["mcp:tools", "mcp:resources", "mcp:prompts"]
   ```

   **Examples for common providers:**
   ```yaml
   # Ory Hydra/Kratos
   oauth:
     issuer: "https://your-ory-hydra.example.com"
     authorization_endpoint: "https://your-ory-hydra.example.com/oauth2/auth"
     token_endpoint: "https://your-ory-hydra.example.com/oauth2/token"
     registration_endpoint: "https://your-ory-hydra.example.com/admin/clients"
     introspection_endpoint: "https://your-ory-hydra.example.com/oauth2/introspect"
     userinfo_endpoint: "https://your-ory-kratos.example.com/userinfo"

   # Auth0
   oauth:
     issuer: "https://your-domain.auth0.com"
     authorization_endpoint: "https://your-domain.auth0.com/authorize"
     token_endpoint: "https://your-domain.auth0.com/oauth/token"
     userinfo_endpoint: "https://your-domain.auth0.com/userinfo"
   ```

2. **Create external OAuth gateway**:
   ```ruby
   # app/mcp/external_oauth_gateway.rb
   class ExternalOAuthGateway < ActionMCP::Gateway
     identified_by :user

     protected

     def authenticate!
       token_info = request.env["action_mcp.oauth_token_info"]
       raise ActionMCP::UnauthorizedError unless token_info

       user = resolve_user_from_external_oauth(token_info)
       { user: user }
     end

     private

     def resolve_user_from_external_oauth(token_info)
       # Most OAuth providers use 'sub' field for user ID
       user_id = token_info[:sub]
       return nil unless user_id

       # Look up user by external OAuth subject ID
       user = User.find_by(external_oauth_subject: user_id)

       # If user doesn't exist, create from userinfo endpoint
       unless user
         user_info = fetch_external_userinfo(token_info[:access_token])
         user = User.create!(
           external_oauth_subject: user_id,
           email: user_info["email"],
           name: user_info["name"] || user_info["preferred_username"]
         )
       end

       user
     end

     def fetch_external_userinfo(access_token)
       userinfo_endpoint = ActionMCP.configuration.oauth&.dig(:userinfo_endpoint)
       return {} unless userinfo_endpoint

       response = HTTP.auth("Bearer #{access_token}").get(userinfo_endpoint)
       JSON.parse(response.body)
     rescue => e
       # Failed to fetch userinfo: #{e.message}
       {}
     end
   end
   ```

### Option 3: Custom OAuth Provider

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

## User Resolution Strategies

Your ApplicationGateway needs to handle OAuth user resolution. Here are common strategies:

### Strategy 1: Subject-Based Mapping (Recommended)

```ruby
# app/mcp/application_gateway.rb
class ApplicationGateway < ActionMCP::Gateway
  identified_by :user

  protected

  def authenticate!
    ActionMCP.configuration.authentication_methods.each do |method|
      case method
      when "oauth"
        token_info = request.env["action_mcp.oauth_token_info"]
        if token_info
          user = resolve_user_from_oauth(token_info)
          return { user: user } if user
        end
      end
    end
    raise ActionMCP::UnauthorizedError, "Unauthorized"
  end

  private

  def resolve_user_from_oauth(token_info)
    # Use OAuth 'sub' claim for user identification
    user_id = token_info[:sub]
    return nil unless user_id

    # Find existing user by external OAuth subject
    user = User.find_by(external_oauth_subject: user_id)

    # If user doesn't exist, create from available token info
    unless user
      user = User.create!(
        external_oauth_subject: user_id,
        email: token_info[:email] || "#{user_id}@oauth.local"
      )
    end

    user
  end
end
```

### Strategy 2: Email-Based Mapping

```ruby
def resolve_user_from_oauth(token_info)
  email = token_info[:email]
  return nil unless email

  # Find or create user by email
  User.find_or_create_by(email: email) do |user|
    user.external_oauth_subject = token_info[:sub]
  end
end
```

### Strategy 3: Custom Claims Mapping

```ruby
def resolve_user_from_oauth(token_info)
  # Use custom claims based on your OAuth provider
  case token_info[:iss] # issuer
  when "https://your-ory-hydra.example.com"
    resolve_ory_user(token_info)
  when "https://your-domain.auth0.com"
    resolve_auth0_user(token_info)
  else
    resolve_default_user(token_info)
  end
end

private

def resolve_ory_user(token_info)
  User.find_or_create_by(external_oauth_subject: token_info[:sub]) do |user|
    user.email = token_info[:email]
    user.name = token_info[:name]
  end
end

def resolve_auth0_user(token_info)
  User.find_or_create_by(external_oauth_subject: token_info[:sub]) do |user|
    user.email = token_info[:email]
    user.name = token_info[:nickname] || token_info[:name]
  end
end
```

### Database Schema

Add OAuth support to your User model:

```ruby
# Migration for OAuth integration
class AddOAuthToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :external_oauth_subject, :string
    add_index :users, :external_oauth_subject, unique: true
  end
end
```

**For multiple OAuth providers with single column:**

```ruby
# User model
class User < ApplicationRecord
  validates :external_oauth_subject, uniqueness: true, allow_nil: true

  # Optional: Track which OAuth provider was used
  def oauth_provider
    case external_oauth_subject
    when /^google-oauth2/
      'google'
    when /^github/
      'github'
    else
      # Detect from email domain or other patterns
      email&.split('@')&.last
    end
  end
end
```

**For multiple OAuth providers with separate columns (if needed):**

```ruby
# Migration for multiple provider support
class AddMultipleOAuthToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :oauth_provider, :string
    add_column :users, :oauth_subject, :string
    add_index :users, [:oauth_provider, :oauth_subject], unique: true
  end
end

# User model
class User < ApplicationRecord
  validates :oauth_subject, uniqueness: { scope: :oauth_provider }

  def self.find_by_oauth(provider, subject)
    find_by(oauth_provider: provider, oauth_subject: subject)
  end
end
```

## Client Integration

### Editor Configuration

To use OAuth with your editor, create or update your MCP configuration file (`.mcp.json` or equivalent):

**For built-in OAuth provider:**

```json
{
  "mcpServers": {
    "action_mcp": {
      "type": "http",
      "url": "http://localhost:62770",
      "auth": {
        "type": "oauth",
        "authorization_url": "http://localhost:62770/oauth/authorize",
        "token_url": "http://localhost:62770/oauth/token",
        "registration_url": "http://localhost:62770/oauth/register",
        "scopes": ["mcp:tools", "mcp:resources", "mcp:prompts"]
      }
    }
  }
}
```

**For external OAuth providers:**

```json
{
  "mcpServers": {
    "action_mcp": {
      "type": "http",
      "url": "http://localhost:62770",
      "auth": {
        "type": "oauth",
        "authorization_url": "https://your-oauth-provider.example.com/oauth2/auth",
        "token_url": "https://your-oauth-provider.example.com/oauth2/token",
        "registration_url": "https://your-oauth-provider.example.com/oauth2/register",
        "scopes": ["mcp:tools", "mcp:resources", "mcp:prompts"]
      }
    }
  }
}
```

**Quick reference for common providers:**

```json
// Ory Hydra
"auth": {
  "type": "oauth",
  "authorization_url": "https://your-ory-hydra.example.com/oauth2/auth",
  "token_url": "https://your-ory-hydra.example.com/oauth2/token",
  "registration_url": "https://your-ory-hydra.example.com/admin/clients",
  "scopes": ["mcp:tools", "mcp:resources", "mcp:prompts"]
}

// Auth0
"auth": {
  "type": "oauth",
  "authorization_url": "https://your-domain.auth0.com/authorize",
  "token_url": "https://your-domain.auth0.com/oauth/token",
  "scopes": ["mcp:tools", "mcp:resources", "mcp:prompts"]
}

// Keycloak
"auth": {
  "type": "oauth",
  "authorization_url": "https://your-keycloak.example.com/auth/realms/YOUR_REALM/protocol/openid-connect/auth",
  "token_url": "https://your-keycloak.example.com/auth/realms/YOUR_REALM/protocol/openid-connect/token",
  "scopes": ["mcp:tools", "mcp:resources", "mcp:prompts"]
}
```

### Using Bearer Tokens

Clients authenticate by including a Bearer token in the Authorization header:

```bash
curl -H "Authorization: Bearer <access_token>" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' \
     http://localhost:62770
```

### OAuth Authorization Flow

1. **Client Registration** (if dynamic registration enabled)
2. **Authorization Request** with PKCE challenge
3. **User Authorization**
4. **Authorization Code Exchange** with PKCE verifier
5. **API Access** with Bearer token
6. **Token Refresh** (if refresh tokens issued)

### Custom MCP Client Integration

For custom MCP clients, implement the OAuth 2.1 flow:

```javascript
const client = new MCPClient({
  url: 'http://localhost:62770',
  auth: {
    type: 'oauth',
    clientId: 'your-client-id',
    clientSecret: 'your-client-secret', // Optional for public clients
    authorization_url: 'http://localhost:62770/oauth/authorize',
    token_url: 'http://localhost:62770/oauth/token',
    scopes: ['mcp:tools', 'mcp:resources', 'mcp:prompts']
  }
});
```

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
  # Log request path: #{env['PATH_INFO']}
  # Log auth header: #{env['HTTP_AUTHORIZATION']}
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
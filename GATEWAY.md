# ActionMCP Gateway Guide

This document explains the Gateway concept in ActionMCP, how it authenticates callers, and how tools/prompts/resources receive the caller context.

## What the Gateway Does
- Runs **before** any tool/prompt/resource.
- Authenticates the request and resolves one or more identifiers.
- Seeds `ActionMCP::Current` with those identifiers for downstream use.
- Rejects the request with `ActionMCP::UnauthorizedError` if authentication fails.

## Lifecycle
1) Request hits the MCP endpoint.  
2) `ApplicationGateway#authenticate!` executes.  
3) On success, it returns a hash whose keys match `identified_by` declarations.  
4) Identifiers are stored on `ActionMCP::Current` and the session; tools/prompts/resources can read them via helper methods (`current_user`, etc.).  
5) On failure, a JSON-RPC error (`-32001 Unauthorized`) is returned; no tool code runs.

## Implementing `ApplicationGateway`
`action_mcp:install` generates `app/mcp/application_gateway.rb`. You customize only `identified_by` and `authenticate!`.

```ruby
# app/mcp/application_gateway.rb
class ApplicationGateway < ActionMCP::Gateway
  identified_by :user, :organization

  protected

  def authenticate!
    token = extract_bearer_token
    raise ActionMCP::UnauthorizedError, "Missing token" unless token

    payload = ActionMCP::JwtDecoder.decode(token)
    user = User.find_by(id: payload["sub"])
    org  = Organization.find_by(id: payload["org_id"])

    raise ActionMCP::UnauthorizedError, "Unauthorized" unless user && org

    { user: user, organization: org }
  end
end
```

### Accessing Identifiers
Inside tools/prompts/resources:
```ruby
class MyTool < ApplicationMCPTool
  def perform
    render text: "Hi #{current_user.name} from #{current_organization.name}"
  end
end
```
`current_user` and `current_organization` are provided via `ActionMCP::Current`.

## Authentication Patterns
- **Bearer JWT (recommended):** Use `extract_bearer_token`, validate signature, resolve user/org/roles.
- **API Key header:** Look up a key table; return identifiers; throttle invalid attempts.
- **Session cookies:** Generally avoid—MCP traffic is not browser-oriented and runs best stateless.

## Authorization vs Authentication
- Gateway authenticates and attaches identity.  
- Authorization should stay in tools/prompts (e.g., `authorize! current_user, :action`), because permissions depend on the specific operation.

## Error Handling
- Raise `ActionMCP::UnauthorizedError` for auth failures; include only user-safe messages.  
- Avoid leaking reason details (e.g., “token expired”) unless you are certain they’re safe to expose.

## Testing Checklist
- Missing token → unauthorized.  
- Invalid token → unauthorized.  
- Valid token → identifiers set (`ActionMCP::Current.user`).  
- Multi-tenant: ensure the correct org/tenant is bound.

## Production Hardening Tips
- Keep `authenticate!` fast (DB lookups OK; no remote HTTP).  
- Prefer short-lived tokens; rotate signing keys.  
- Log auth failures at warn level without secrets.  
- Pair with `mcp_vanilla.ru` if web middleware interferes; Gateway still runs as usual.

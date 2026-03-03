# ActionMCP Gateway Guide

This document explains the Gateway concept in ActionMCP, how it authenticates callers, and how tools/prompts/resources receive the caller context.

## What the Gateway Does

- Runs **before** any tool/prompt/resource (on non-initialize requests).
- Tries registered identifier classes in order until one succeeds.
- Seeds `ActionMCP::Current` with resolved identities for request-scoped access.
- Optionally persists context on the session via `configure_session`.
- Rejects the request with `ActionMCP::UnauthorizedError` if all identifiers fail.

## Lifecycle

1. Request hits the MCP endpoint.
2. Gateway tries each registered identifier class in order.
3. First successful identifier returns the resolved identity (e.g., a User).
4. Identity is stored on `ActionMCP::Current` (request-scoped).
5. `configure_session(session)` hook is called — optionally persist data on the session.
6. Tools/prompts/resources access context via `ActionMCP::Current` or `session.session_data`.
7. On failure, a JSON-RPC error is returned; no tool code runs.

## Implementing `ApplicationGateway`

`action_mcp:install` generates `app/mcp/application_gateway.rb`. You register identifier classes and optionally override hooks.

```ruby
# app/mcp/application_gateway.rb
class ApplicationGateway < ActionMCP::Gateway
  identified_by JwtIdentifier, ApiKeyIdentifier

  # Optionally persist auth context on the session
  def configure_session(session)
    session.session_data = {
      "user_id" => user.id,
      "company_id" => user.company_id
    }
  end
end
```

### Creating Identifier Classes

Each identifier class inherits from `ActionMCP::GatewayIdentifier` and implements `resolve`:

```ruby
class JwtIdentifier < ActionMCP::GatewayIdentifier
  identifier :user
  authenticates :jwt

  def resolve
    token = extract_bearer_token
    raise Unauthorized, "Missing token" unless token

    payload = JWT.decode(token, secret_key).first
    User.find(payload["sub"])
  end
end
```

### Accessing Identifiers

Inside tools/prompts/resources, use `ActionMCP::Current`:

```ruby
class MyTool < ApplicationMCPTool
  def perform
    render text: "Hi #{current_user.name}"
  end
end
```

`current_user` is provided via `ActionMCP::Current`.

## Persisting Context on Sessions

`ActionMCP::Current` is request-scoped — it resets after every request. If you need auth context to survive across requests (for audit trails, background jobs, or tools that need session-scoped metadata), use `configure_session`:

```ruby
class ApplicationGateway < ActionMCP::Gateway
  identified_by WardenIdentifier

  def configure_session(session)
    session.session_data = {
      "user_id" => user.id,
      "tenant_id" => user.tenant_id,
      "roles" => user.roles.pluck(:name)
    }
  end
end
```

Tools read it via the `session_data` helper:

```ruby
class AuditTool < ApplicationMCPTool
  def perform
    user_id = session_data["user_id"]
    render text: "Audit entry for user #{user_id}"
  end
end
```

### When to Use `ActionMCP::Current` vs `session.session_data`

| | `ActionMCP::Current` | `session.session_data` |
|---|---|---|
| **Scope** | Current request only | Persisted on the session |
| **Access** | `current_user`, `current_gateway` | `session_data["key"]` |
| **Use for** | Authorization checks, rendering | Audit trails, background jobs, cross-request context |
| **Set by** | Gateway automatically | `configure_session` hook |

The hook is called on every authenticated request, so implementations should be **idempotent**. The session is only saved when `session_data` actually changes (dirty tracking).

## Authentication Patterns

- **Bearer JWT (recommended):** Use `extract_bearer_token`, validate signature, resolve user/org/roles.
- **API Key header:** Look up a key table; return identifiers; throttle invalid attempts.
- **Warden/Devise:** Use the built-in `WardenIdentifier` or `DeviseIdentifier`.
- **Session cookies:** Generally avoid — MCP traffic is not browser-oriented and runs best stateless.

## Authorization vs Authentication

- Gateway authenticates and attaches identity.
- Authorization should stay in tools/prompts (e.g., `authorize! current_user, :action`), because permissions depend on the specific operation.

## Profile Switching

Override `apply_profile_from_authentication` to switch profiles based on the authenticated user:

```ruby
class ApplicationGateway < ActionMCP::Gateway
  identified_by UserIdentifier

  def apply_profile_from_authentication(identities)
    if user&.admin?
      use_profile(:admin)
    else
      use_profile(:minimal)
    end
  end
end
```

## Error Handling

- Raise `ActionMCP::UnauthorizedError` for auth failures; include only user-safe messages.
- Avoid leaking reason details (e.g., "token expired") unless you are certain they're safe to expose.

## Testing Checklist

- Missing token → unauthorized.
- Invalid token → unauthorized.
- Valid token → identifiers set (`ActionMCP::Current.user`).
- Multi-tenant: ensure the correct org/tenant is bound.
- `configure_session` persists expected data on the session.

## Production Hardening Tips

- Keep `authenticate!` fast (DB lookups OK; no remote HTTP).
- Prefer short-lived tokens; rotate signing keys.
- Log auth failures at warn level without secrets.
- `configure_session` should be idempotent — avoid side effects beyond setting `session_data`.

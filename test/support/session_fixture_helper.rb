# frozen_string_literal: true

module SessionFixtureHelper
  # Maps fixture attributes to session payload attributes
  # This reduces duplication when creating sessions from fixtures
  def session_payload_from_fixture(fixture)
    {
      initialized: fixture.initialized,
      status: fixture.status,
      role: fixture.role,
      messages_count: fixture.messages_count,
      protocol_version: fixture.protocol_version,
      server_info: fixture.server_info,
      server_capabilities: fixture.server_capabilities,
      tool_registry: fixture.tool_registry,
      prompt_registry: fixture.prompt_registry,
      resource_registry: fixture.resource_registry
    }
  end

  # Stores the fixture session in the server session store, ready for requests.
  def create_initialized_session(fixture_name = :step1_session)
    fixture = action_mcp_sessions(fixture_name)
    ActionMCP::Server.session_store.create_session(fixture.id, session_payload_from_fixture(fixture))
  end
end

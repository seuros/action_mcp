# frozen_string_literal: true

require "test_helper"

class DebugInitTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure configuration is properly loaded before creating sessions
    ActionMCP.configuration.name = "ActionMCP Dummy"
    ActionMCP.configuration.load_profiles
  end

  test "initialization follows MCP spec" do
    post "/", params: {
      jsonrpc: "2.0",
      id: "init-1",
      method: "initialize",
      params: {
        protocolVersion: "2025-11-25",
        clientInfo: { name: "Test Client", version: "1.0" },
        capabilities: {
          roots: { listChanged: true },
          sampling: {}
        }
      }
    }.to_json, headers: {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream"
    }

    assert_response :success
    body = response.parsed_body

    # Verify JSON-RPC response structure
    assert_equal "2.0", body["jsonrpc"]
    assert_equal "init-1", body["id"]
    assert body["result"], "Expected result but got: #{body.inspect}"

    # Verify MCP protocol version matches request
    assert_equal "2025-11-25", body["result"]["protocolVersion"]

    # Verify server info contains expected values
    assert_equal "ActionMCP Dummy", body["result"]["serverInfo"]["name"]
    assert_equal "9.9.9", body["result"]["serverInfo"]["version"]

    # Verify capabilities structure matches expected server capabilities
    expected_capabilities = {
      "tools" => { "listChanged" => true },
      "prompts" => { "listChanged" => true },
      "resources" => { "subscribe" => false, "listChanged" => true },
      "completions" => {}
    }
    assert_equal expected_capabilities, body["result"]["capabilities"]
  end

  test "initialization advertises mcp apps extension when enabled" do
    original_mcp_apps_enabled = ActionMCP.configuration.mcp_apps_enabled
    ActionMCP.configuration.mcp_apps_enabled = true
    post "/", params: {
      jsonrpc: "2.0",
      id: "init-apps",
      method: "initialize",
      params: {
        protocolVersion: "2025-11-25",
        clientInfo: { name: "Test Client", version: "1.0" },
        capabilities: {
          extensions: {
            "io.modelcontextprotocol/ui" => {
              mimeTypes: [ ActionMCP::MIME_TYPE_APP_HTML ]
            }
          }
        }
      }
    }.to_json, headers: {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream"
    }

    assert_response :success
    extensions = response.parsed_body.dig(
      "result",
      "capabilities",
      "extensions"
    )

    assert_equal(
      { "mimeTypes" => [ ActionMCP::MIME_TYPE_APP_HTML ] },
      extensions["io.modelcontextprotocol/ui"]
    )
  ensure
    ActionMCP.configuration.mcp_apps_enabled = original_mcp_apps_enabled
  end
end

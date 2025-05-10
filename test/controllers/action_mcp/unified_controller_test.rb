require "test_helper"

module ActionMCP
  class UnifiedControllerTest < ActionDispatch::IntegrationTest
    def app
      ActionMCP::Engine
    end

    setup { @session = Session.create!(initialized: true) }

    def json_headers(extra = {})
      {
        "CONTENT_TYPE"  => "application/json",
        "ACCEPT"        => "application/json, text/event-stream"
      }.merge(extra)
    end

    ### ---------- POST -------------------------------------------------

    test "POST initialize creates a session and returns 200 JSON" do
      body = {
        jsonrpc: "2.0",
        id:      "abc",
        method:  "initialize",
        params:  { protocolVersion: "2025-03-26", clientInfo: {}, capabilities: {} }
      }.to_json

      post "/mcp", headers: json_headers, params: body
      assert_response :ok
      assert_equal "application/json", response.media_type
      assert response.headers["Mcp-Session-Id"].present?
    end

    test "POST normal request without session id is not acceptable" do
      body = { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json
      post "/mcp", headers: json_headers, params: body
      assert_response :ok
      assert_equal -32600, response.parsed_body["error"]["code"]
      assert_equal "Mcp-Session-Id header is required for this request.", response.parsed_body["error"]["message"]
    end

    ### ---------- GET (SSE) -------------------------------------------

    test "GET without Accept: text/event-stream → 406" do
      get "/mcp", headers: { "Mcp-Session-Id" => @session.id, "ACCEPT" => "application/json" }
      assert_response :ok
      assert_equal -32002, response.parsed_body["error"]["code"]
      assert_equal "Client must accept 'text/event-stream' for GET requests.", response.parsed_body["error"]["message"]
    end

    test "GET SSE returns 200 and streams" do
      get "/mcp", headers: {
        "Mcp-Session-Id" => @session.id,
        "ACCEPT"         => "text/event-stream"
      }

      assert_response :success
      assert_equal "text/event-stream", response.media_type
    end

    test "DELETE terminates session" do
      delete "/mcp", headers: { "Mcp-Session-Id" => @session.id }
      assert_response :no_content
    end

    test "DELETE terminates session with wrong id" do
      delete "/mcp", headers: { "Mcp-Session-Id" => "non-existent-session-id" }
      assert_response :ok
      assert_equal -32001, response.parsed_body["error"]["code"]
      assert_equal "Session not found.", response.parsed_body["error"]["message"]
    end
  end
end

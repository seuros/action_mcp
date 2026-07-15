# frozen_string_literal: true

require "test_helper"

class NonRootEndpointPathTest < ActionDispatch::IntegrationTest
  ENDPOINT_ALIASES = %w[/mcp/ /mcp.json].freeze

  test "non-root route aliases cannot bypass Origin validation" do
    ENDPOINT_ALIASES.each do |path|
      get path
      assert_response :ok

      get path, headers: { "Origin" => "https://evil.example" }
      assert_response :forbidden
    end
  end

  test "non-root route aliases cannot bypass JSON-RPC validation" do
    ENDPOINT_ALIASES.each do |path|
      post path,
           params: { jsonrpc: "2.0", id: "valid", method: "example/test" }.to_json,
           headers: json_headers
      assert_response :ok

      post path, params: '{"jsonrpc":', headers: json_headers
      assert_response :bad_request
      assert_equal(-32_700, response.parsed_body.dig("error", "code"))
    end
  end

  private

  def app
    @app ||= build_app
  end

  def build_app
    routes = ActionDispatch::Routing::RouteSet.new
    endpoint = lambda do |_env|
      [ 200, { "Content-Type" => "application/json" }, [ '{"accepted":true}' ] ]
    end
    routes.draw do
      get "/mcp", to: endpoint
      post "/mcp", to: endpoint
    end

    endpoint_paths = [ ActionMCP::Engine.endpoint_path_matcher("/mcp") ].freeze
    jsonrpc_app = JSONRPC_Rails::Middleware::Validator.new(
      routes,
      endpoint_paths,
      payload_validator: ActionMCP::ProtocolValidator,
      batch_policy: :reject,
      require_json_content_type: true
    )
    ActionMCP::Middleware::OriginValidation.new(jsonrpc_app, endpoint_paths)
  end

  def json_headers
    {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream"
    }
  end
end

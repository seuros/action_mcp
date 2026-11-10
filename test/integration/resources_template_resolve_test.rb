# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ResourcesTemplateResolveTest < ActionDispatch::IntegrationTest
    setup do
      @session_id = initialize_mcp_session(path: action_mcp.mcp_post_path)
      assert_response :accepted
    end

    test "resources/read successfully resolves ProductsTemplate with valid product ID" do
      # Test resources/read with ProductsTemplate URI
      session_post("resources/read", { uri: "ecommerce://products/123" }, id: 2)

      assert_response :success
      result = JSON.parse(response.body)

      # Verify successful response
      assert_equal "2.0", result["jsonrpc"]
      assert_equal 2, result["id"]
      assert_nil result["error"], "Expected no error, but got: #{result["error"]}"
      assert_not_nil result["result"]
      assert_not_nil result["result"]["contents"]
      assert_equal 1, result["result"]["contents"].size

      # Verify MCP-compliant ReadResourceResult content shape
      content = result["result"]["contents"][0]
      assert_equal "ecommerce://products/123", content["uri"]
      assert_equal "application/json", content["mimeType"]
      # Content::Resource returns text with JSON data
      assert_not_nil content["text"]
      parsed = JSON.parse(content["text"])
      assert_equal "123", parsed["id"].to_s
    end

    test "resources/read returns resource not found error for ProductsTemplate with negative product ID" do
      # Test resources/read with negative product ID that won't be found
      session_post("resources/read", { uri: "ecommerce://products/-111" }, id: 2)

      assert_response :success
      result = JSON.parse(response.body)

      # Verify error response for non-existent resource
      assert_equal "2.0", result["jsonrpc"]
      assert_equal 2, result["id"]
      assert_not_nil result["error"], "Expected an error for non-existent product"
      assert_equal(-32002, result["error"]["code"], "Expected resource not found error code")
      assert_match(/Resource not found/, result["error"]["message"])
      assert_equal "template://ProductsTemplate", result["error"]["data"]["uri"]
      assert_nil result["result"]
    end

    private

    def session_post(method, params = nil, **options)
      mcp_post(method, params, path: action_mcp.mcp_post_path, session_id: @session_id, **options)
    end
  end
end

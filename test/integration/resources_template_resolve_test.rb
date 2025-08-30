# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ResourcesTemplateResolveTest < ActionDispatch::IntegrationTest
    setup do
      # Initialize session first
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 1,
             method: "initialize",
             params: {
               clientInfo: { name: "test", version: "1.0" },
               protocolVersion: ActionMCP::LATEST_VERSION
             }
           }.to_json,
           headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

      assert_response :success
      session_id = response.headers["Mcp-Session-Id"]
      assert_not_nil session_id

      # Complete initialization
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             method: "notifications/initialized"
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => session_id
           }

      assert_response :accepted

      @session_id = session_id
    end

    test "resources/read successfully resolves ProductsTemplate with valid product ID" do
      # Test resources/read with ProductsTemplate URI
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 2,
             method: "resources/read",
             params: { uri: "ecommerce://products/123" }
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)

      # Verify successful response
      assert_equal "2.0", result["jsonrpc"]
      assert_equal 2, result["id"]
      assert_nil result["error"], "Expected no error, but got: #{result["error"]}"
      assert_not_nil result["result"]
      assert_not_nil result["result"]["contents"]
      assert_equal 1, result["result"]["contents"].size

      # Verify the ProductsTemplate was processed correctly
      content = result["result"]["contents"][0]
      assert_equal "ecommerce://products/123", content["uri"]
      assert_equal "Product 123", content["name"]
      assert_match(/Product information for product 123/, content["description"])
      assert_equal "application/json", content["mimeType"]
    end

    test "resources/read returns method_not_found error for ProductsTemplate with negative product ID" do
      # Test resources/read with negative product ID that won't be found
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 2,
             method: "resources/read",
             params: { uri: "ecommerce://products/-111" }
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)

      # Verify error response for non-existent resource
      assert_equal "2.0", result["jsonrpc"]
      assert_equal 2, result["id"]
      assert_not_nil result["error"], "Expected an error for non-existent product"
      assert_equal(-32601, result["error"]["code"], "Expected method_not_found error code")
      assert_match(/Resource not found/, result["error"]["message"])
      assert_equal "template://ProductsTemplate", result["error"]["data"]["uri"]
      assert_nil result["result"]
    end
  end
end

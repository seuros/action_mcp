# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ResourcesListTest < ActionDispatch::IntegrationTest
    setup do
      # Initialize session
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

    test "resources/list returns concrete resources from templates implementing list" do
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 2,
             method: "resources/list"
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)

      assert_equal "2.0", result["jsonrpc"]
      assert_equal 2, result["id"]
      assert_nil result["error"], "Expected no error, but got: #{result["error"]}"
      assert_not_nil result["result"]
      assert_not_nil result["result"]["resources"]

      resources = result["result"]["resources"]
      # ProductsTemplate lists 3 products
      product_uris = resources.select { |r| r["uri"].start_with?("ecommerce://products/") }
      assert_equal 3, product_uris.size

      # Verify resource shape
      product = product_uris.find { |r| r["uri"] == "ecommerce://products/1" }
      assert_not_nil product
      assert_equal "Product 1", product["name"]
      assert_equal "Product #1", product["title"]
      assert_equal "application/json", product["mimeType"]
    end

    test "resources/list supports cursor pagination" do
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 2,
             method: "resources/list",
             params: {}
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)

      # With few resources, no nextCursor should be present
      assert_nil result["result"]["nextCursor"]
    end

    test "resources/list returns invalid params for malformed cursor" do
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 22,
             method: "resources/list",
             params: { cursor: "not-base64" }
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)

      assert_not_nil result["error"]
      assert_equal(-32_602, result["error"]["code"])
      assert_match(/Invalid cursor value/, result["error"]["message"])
    end

    test "resources/templates/list returns templates" do
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 3,
             method: "resources/templates/list"
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)

      assert_not_nil result["result"]
      templates = result["result"]["resourceTemplates"]
      assert_not_nil templates
      assert templates.size > 0

      # Verify template shape
      template = templates.find { |t| t["uriTemplate"]&.include?("products") }
      assert_not_nil template, "Expected to find products template"
      assert_not_nil template["uriTemplate"]
      assert_not_nil template["name"]
    end

    test "resources/templates/list accepts cursor param without error" do
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 4,
             method: "resources/templates/list",
             params: { cursor: nil }
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)
      assert_nil result["error"], "Expected no error with cursor param"
      assert_not_nil result["result"]["resourceTemplates"]
    end

    test "resources/templates/list returns invalid params for non-string cursor" do
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 44,
             method: "resources/templates/list",
             params: { cursor: 123 }
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)

      assert_not_nil result["error"]
      assert_equal(-32_602, result["error"]["code"])
      assert_match(/Invalid cursor value/, result["error"]["message"])
    end

    test "resources/read returns MCP-compliant content shape" do
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 5,
             method: "resources/read",
             params: { uri: "ecommerce://products/1" }
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)

      assert_nil result["error"]
      contents = result["result"]["contents"]
      assert_equal 1, contents.size

      content = contents[0]
      assert_equal "ecommerce://products/1", content["uri"]
      assert_equal "application/json", content["mimeType"]
      assert_not_nil content["text"], "Expected text field in read content"
    end

    test "resources/read returns error for unknown URI" do
      post action_mcp.mcp_post_path,
           params: {
             jsonrpc: "2.0",
             id: 6,
             method: "resources/read",
             params: { uri: "unknown://resource/123" }
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      result = JSON.parse(response.body)

      assert_not_nil result["error"]
      assert_equal(-32002, result["error"]["code"])
      assert_match(/Resource not found/, result["error"]["message"])
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ResourcesListTest < ActionDispatch::IntegrationTest
    setup do
      @session_id = initialize_mcp_session(path: action_mcp.mcp_post_path)
      assert_response :accepted
    end

    test "resources/list returns concrete resources from templates implementing list" do
      session_post("resources/list", id: 2)

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
      session_post("resources/list", {}, id: 2)

      assert_response :success
      result = JSON.parse(response.body)

      # With few resources, no nextCursor should be present
      assert_nil result["result"]["nextCursor"]
    end

    test "resources/list returns invalid params for malformed cursor" do
      session_post("resources/list", { cursor: "not-base64" }, id: 22)

      assert_response :success
      result = JSON.parse(response.body)

      assert_not_nil result["error"]
      assert_equal(-32_602, result["error"]["code"])
      assert_match(/Invalid cursor/, result["error"]["message"])
    end

    test "resources/templates/list returns templates" do
      session_post("resources/templates/list", id: 3)

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

    test "resources/templates/list rejects null cursor" do
      session_post("resources/templates/list", { cursor: nil }, id: 4)

      assert_response :success
      result = JSON.parse(response.body)

      assert_not_nil result["error"]
      assert_equal(-32_602, result["error"]["code"])
      assert_match(/cursor.*not a string/i, result["error"]["message"])
    end

    test "resources/templates/list returns invalid params for non-string cursor" do
      session_post("resources/templates/list", { cursor: 123 }, id: 44)

      assert_response :success
      result = JSON.parse(response.body)

      assert_not_nil result["error"]
      assert_equal(-32_602, result["error"]["code"])
      assert_match(/cursor.*not a string/i, result["error"]["message"])
    end

    test "resources/read returns MCP-compliant content shape" do
      session_post("resources/read", { uri: "ecommerce://products/1" }, id: 5)

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
      session_post("resources/read", { uri: "unknown://resource/123" }, id: 6)

      assert_response :success
      result = JSON.parse(response.body)

      assert_not_nil result["error"]
      assert_equal(-32002, result["error"]["code"])
      assert_match(/Resource not found/, result["error"]["message"])
    end

    private

    def session_post(method, params = nil, **options)
      mcp_post(method, params, path: action_mcp.mcp_post_path, session_id: @session_id, **options)
    end
  end
end

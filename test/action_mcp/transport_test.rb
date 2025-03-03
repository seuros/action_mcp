require "test_helper"

module ActionMCP
  class TransportTest < ActiveSupport::TestCase
    def setup
      @output = StringIO.new
      @transport = TransportHandler.new(@output)
    end

    # Helper method to parse the last JSON message written to the output.
    def parse_last_output
      MultiJson.load(@output.string.lines.last)
    end

    # =========================================================================
    # Capabilities (Group – Request ID: 1)
    # =========================================================================
    test "send_capabilities outputs valid capabilities response" do
      request_id = 1
      @transport.send_capabilities(request_id)
      response = parse_last_output
      result = response["result"]

      assert_equal "2024-11-05", result["protocolVersion"]
      assert_equal "ActionMCP Dummy", result["serverInfo"]["name"]
      assert_equal "9.9.9", result["serverInfo"]["version"]
      # When registries are empty, keys :tools, :prompts, and :resources are omitted.
      assert_includes(result["capabilities"], "tools")
      assert_includes(result["capabilities"], "prompts")
      assert_includes(result["capabilities"], "resources")
      # Logging is enabled in our configuration.
      assert_includes(result["capabilities"], "logging")
    end

    # =========================================================================
    # Tools (Group – Request IDs: 2–3)
    # =========================================================================
    test "send_tools_list outputs tools list" do
      request_id = 2
      @transport.send_tools_list(request_id)
      response = parse_last_output
      tools = response["result"]["tools"]
      assert_equal 8, tools.size
      assert_equal "add", tools.first["name"]
    end

    test "send_tools_call logs call details without writing a JSON response" do
      request_id = 3
      payload = {
        name: "calculate_sum",
        arguments: { a: 1, b: 1 },
        _meta: { progressToken: 0 }
      }
      @transport.send_tools_call(request_id, payload[:name], payload[:arguments], payload[:_meta])
      # This method only logs its call; no additional JSON response is sent.
      string = @output.string
      assert_equal(
        {
          "jsonrpc" => "2.0",
          "id" => 3,
          "result" => { "content" => [ { "type" => "text", "text" => "2.0" } ] }
        },
        MultiJson.load(string)
      )
    end

    # =========================================================================
    # Resources (Group – Request IDs: 4–8; Not Implemented)
    # =========================================================================
    test "send_resources_list outputs resources list" do
      skip "Resources are not implemented"
      request_id = 4
      @transport.send_resources_list(request_id)
      response = parse_last_output
      resources = response["result"]["resources"]
      assert_equal [], resources
    end

    test "send_resource_templates_list outputs templates list" do
      skip "Resources are not implemented"
      request_id = 5
      @transport.send_resource_templates_list(request_id)
      response = parse_last_output
      templates = response["result"]["resourceTemplates"]
      assert_equal [], templates
    end

    test "send_resource_read returns error when uri is missing" do
      skip "Resources are not implemented"
      request_id = 6
      params = { "uri" => "" }
      @transport.send_resource_read(request_id, params)
      response = parse_last_output
      assert response["error"]
      assert_match(/Missing 'uri'/, response["error"]["message"])
    end

    test "send_resource_read returns resource content when found" do
      skip "Resources are not implemented"
      request_id = 7
      params = { "uri" => "dummy_uri" }
      @transport.send_resource_read(request_id, params)
      response = parse_last_output
      contents = response["result"]["contents"]
      assert_equal "Hello world", contents.first["content"]
    end

    test "send_resource_read returns error when resource not found" do
      skip "Resources are not implemented"
      request_id = 8
      params = { "uri" => "nonexistent" }
      @transport.send_resource_read(request_id, params)
      response = parse_last_output
      assert response["error"]
      assert_match(/Resource not found/, response["error"]["message"])
    end

    # =========================================================================
    # Prompts (Group – Request IDs: 9–11)
    # =========================================================================
    test "send_prompts_list outputs prompts list" do
      request_id = 9
      @transport.send_prompts_list(request_id)
      response = parse_last_output
      prompts = response["result"]["prompts"]
      assert_equal 2, prompts.size
      assert_equal "analyze-code", prompts.first["name"]
    end

    test "send_prompts_get returns error when name is missing" do
      request_id = 10
      @transport.send_prompts_get(request_id, "lost", {})
      response = parse_last_output
      assert response["error"]
      assert_match("Prompt not found: lost", response["error"]["message"])
    end

    test "send_prompts_get returns prompt when found" do
      request_id = 11
      name = "summarize_text"
      params = { "text" => "Hello world" }
      @transport.send_prompts_get(request_id, name, params)
      response = parse_last_output
      prompt = response["result"]["messages"]
      assert_equal [ { "role" => "user", "content" => { "summary" => "[CONCISE] Hello world" } } ], prompt
    end

    # =========================================================================
    # JSON-RPC & Miscellaneous (Group – Request IDs: 12–13 and Notification)
    # =========================================================================
    test "send_pong outputs an empty result" do
      request_id = 12
      @transport.send_pong(request_id)
      response = parse_last_output
      assert_equal({}, response["result"])
    end

    test "send_jsonrpc_response outputs correct response" do
      request_id = 13
      result = { "key" => "value" }
      @transport.send_jsonrpc_response(request_id, result: result)
      response = parse_last_output
      assert_equal result, response["result"]
      assert_equal request_id, response["id"]
    end

    test "send_jsonrpc_notification outputs correct notification" do
      # Note: notifications do not include a request ID.
      method = "test_notification"
      params = { "foo" => "bar" }
      @transport.send_jsonrpc_notification(method, params)
      response = parse_last_output
      assert_equal method, response["method"]
      assert_equal params, response["params"]
    end
  end
end

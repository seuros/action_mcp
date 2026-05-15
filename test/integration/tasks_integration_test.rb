# frozen_string_literal: true

require "test_helper"

class TasksIntegrationTest < ActionDispatch::IntegrationTest
  fixtures :action_mcp_sessions

  setup do
    # Force active_record session store for Tasks tests
    # Tasks require persistent sessions since they're stored in DB
    @original_session_store_type = ActionMCP.configuration.server_session_store_type
    @original_tasks_result_strategy = ActionMCP.configuration.tasks_result_strategy
    @original_tasks_result_timeout = ActionMCP.configuration.tasks_result_timeout
    @original_tasks_result_poll_interval = ActionMCP.configuration.tasks_result_poll_interval
    ActionMCP.configuration.server_session_store_type = :active_record
    # Reset the session store singleton by setting it to nil
    ActionMCP::Server.instance_variable_set(:@session_store, nil)

    @session = action_mcp_sessions(:task_master_session)
    @session_id = @session.id

    # Create tasks directly on the fixture session (which is already in the DB)
    @working_task = @session.tasks.create!(
      request_method: "tools/call",
      request_name: "test_tool",
      status_message: "Processing..."
    )

    @completed_task = @session.tasks.create!(
      request_method: "tools/call",
      request_name: "completed_tool",
      result_payload: { content: [ { type: "text", text: "Done!" } ] }
    )
    @completed_task.complete!

    @failed_task = @session.tasks.create!(
      request_method: "tools/call",
      request_name: "failed_tool",
      status_message: "Something went wrong",
      result_payload: {
        isError: true,
        content: [ { type: "text", text: "Something went wrong" } ]
      }
    )
    @failed_task.mark_failed!
  end

  teardown do
    # Restore original session store type
    ActionMCP.configuration.server_session_store_type = @original_session_store_type
    ActionMCP.configuration.tasks_result_strategy = @original_tasks_result_strategy
    ActionMCP.configuration.tasks_result_timeout = @original_tasks_result_timeout
    ActionMCP.configuration.tasks_result_poll_interval = @original_tasks_result_poll_interval
    ActionMCP::Server.instance_variable_set(:@session_store, nil)
  end

  # tasks/get tests
  test "tasks/get returns task data for existing task" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-1",
           method: "tasks/get",
           params: { taskId: @working_task.id }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    assert_equal @working_task.id, body["result"]["taskId"]
    assert_equal "working", body["result"]["status"]
    assert_equal "Processing...", body["result"]["statusMessage"]
    assert body["result"]["createdAt"]
    assert body["result"]["lastUpdatedAt"]
    assert_nil body["result"]["ttl"]
  end

  test "tasks/get returns error for non-existent task" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-2",
           method: "tasks/get",
           params: { taskId: "non-existent-task-id" }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"], "Expected error in response, got: #{body.inspect}"
    assert_match(/not found/, body["error"]["message"])
  end

  test "tasks/get returns error when taskId is missing" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-3",
           method: "tasks/get",
           params: {}
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"], "Expected error in response, got: #{body.inspect}"
    assert_match(/Task ID is required/, body["error"]["message"])
  end

  # tasks/list tests
  test "tasks/list returns all tasks for session" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-4",
           method: "tasks/list"
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    assert body["result"]["tasks"]
    assert_equal 3, body["result"]["tasks"].length

    task_ids = body["result"]["tasks"].map { |t| t["taskId"] }
    assert_includes task_ids, @working_task.id
    assert_includes task_ids, @completed_task.id
    assert_includes task_ids, @failed_task.id
  end

  test "tasks/list supports pagination with cursor" do
    # Create more tasks to test pagination
    10.times do |i|
      @session.tasks.create!(
        request_method: "tools/call",
        request_name: "paginated_tool_#{i}"
      )
    end

    # First page
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-5",
           method: "tasks/list",
           params: {}
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"]["tasks"]
    # Should have 13 tasks total (3 setup + 10 new)
    assert_equal 13, body["result"]["tasks"].length
  end

  test "tasks/list cursor follows recent ordering when ids and insert order diverge" do
    original_page_size = ActionMCP.configuration.pagination_page_size
    ActionMCP.configuration.pagination_page_size = 1
    @session.tasks.delete_all

    older = @session.tasks.create!(
      id: "z-task",
      request_method: "tools/call",
      request_name: "older_task"
    )
    newer = @session.tasks.create!(
      id: "a-task",
      request_method: "tools/call",
      request_name: "newer_task"
    )

    base_time = Time.zone.parse("2026-01-01 00:00:00 UTC")
    older.update_columns(created_at: base_time, updated_at: base_time, last_updated_at: base_time)
    newer.update_columns(created_at: base_time + 1.second, updated_at: base_time + 1.second, last_updated_at: base_time + 1.second)

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-5a",
           method: "tasks/list"
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert_equal [ newer.id ], body["result"]["tasks"].map { |task| task["taskId"] }
    assert body["result"]["nextCursor"]

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-5b",
           method: "tasks/list",
           params: { cursor: body["result"]["nextCursor"] }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert_equal [ older.id ], body["result"]["tasks"].map { |task| task["taskId"] }
    assert_nil body["result"]["nextCursor"]
  ensure
    ActionMCP.configuration.pagination_page_size = original_page_size
  end

  # tasks/result tests
  test "tasks/result returns result for completed task" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-6",
           method: "tasks/result",
           params: { taskId: @completed_task.id }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    assert_equal [ { "type" => "text", "text" => "Done!" } ], body["result"]["content"]
    assert_equal @completed_task.id,
                 body["result"]["_meta"]["io.modelcontextprotocol/related-task"]["taskId"]
  end

  test "tasks/result uses bounded blocking HTTP for non-terminal task" do
    ActionMCP.configuration.tasks_result_strategy = :blocking_http
    ActionMCP.configuration.tasks_result_timeout = 0.01
    ActionMCP.configuration.tasks_result_poll_interval = 0.005

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-7",
           method: "tasks/result",
           params: { taskId: @working_task.id }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"], "Expected bounded wait timeout in response, got: #{body.inspect}"
    assert_equal(-32_000, body["error"]["code"])
    assert_match(/Timed out waiting for task/, body["error"]["message"])
  end

  test "tasks/result returns immediately for input_required task" do
    input_task = @session.tasks.create!(
      request_method: "tools/call",
      request_name: "needs_input",
      result_payload: {
        inputRequests: [
          {
            type: "text",
            name: "confirmation",
            message: "Continue?"
          }
        ]
      }
    )
    input_task.require_input!

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-7-input",
           method: "tasks/result",
           params: { taskId: input_task.id }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected input_required result in response, got: #{body.inspect}"
    assert_equal "confirmation", body["result"]["inputRequests"].first["name"]
    assert_equal input_task.id,
                 body["result"]["_meta"]["io.modelcontextprotocol/related-task"]["taskId"]
  end

  test "tasks/result returns not-complete error for non-terminal task in polling-only mode" do
    ActionMCP.configuration.tasks_result_strategy = :polling_only

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-7-polling",
           method: "tasks/result",
           params: { taskId: @working_task.id }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"], "Expected error in response, got: #{body.inspect}"
    assert_match(/not ready/, body["error"]["message"])
    assert_match(/tasks\/get/, body["error"]["message"])
  end

  test "tasks/result works for failed tasks" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-8",
           method: "tasks/result",
           params: { taskId: @failed_task.id }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    assert_equal true, body["result"]["isError"]
    assert_equal @failed_task.id,
                 body["result"]["_meta"]["io.modelcontextprotocol/related-task"]["taskId"]
  end

  # tasks/cancel tests
  test "tasks/cancel cancels a working task" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-9",
           method: "tasks/cancel",
           params: { taskId: @working_task.id }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    assert_equal "cancelled", body["result"]["status"]
    assert_equal @working_task.id, body["result"]["taskId"]

    @working_task.reload
    assert_equal "cancelled", @working_task.status
  end

  test "tasks/cancel returns error for already terminal task" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-10",
           method: "tasks/cancel",
           params: { taskId: @completed_task.id }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"], "Expected error in response, got: #{body.inspect}"
    assert_match(/Cannot cancel task in terminal status/, body["error"]["message"])
  end

  test "tasks/cancel returns error for non-existent task" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-11",
           method: "tasks/cancel",
           params: { taskId: "fake-task-id" }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"]
    assert_match(/not found/, body["error"]["message"])
  end

  test "tasks/resume is not accepted as a spec task method" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-resume",
           method: "tasks/resume",
           params: { taskId: @working_task.id, input: "value" }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert_equal(-32_601, body["error"]["code"])
    assert_match(/Unknown tasks method/, body["error"]["message"])
  end

  # Protocol version validation
  test "tasks methods require 2025-11-25 protocol version" do
    # Use a 2025-06-18 session (fixture already in DB)
    old_session = action_mcp_sessions(:dr_identity_mcbouncer_session)

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-12",
           method: "tasks/list"
         }.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream",
           "Mcp-Session-Id" => old_session.id,
           "MCP-Protocol-Version" => "2025-06-18"
         }

    assert_response :success
    body = response.parsed_body
    assert_equal(-32_601, body["error"]["code"])
    assert_match(/only available in MCP 2025-11-25/, body["error"]["message"])
  end

  # Task-augmented tool call tests
  test "tool call with task parameter creates task and returns CreateTaskResult" do
    # Enable tasks for this test
    original_tasks_enabled = ActionMCP.configuration.tasks_enabled
    ActionMCP.configuration.tasks_enabled = true

    # Register the async calculator tool
    ActionMCP::ToolsRegistry.register(AsyncCalculatorTool)
    @session.register_tool(AsyncCalculatorTool)
    @session.save!

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "task-tool-1",
           method: "tools/call",
           params: {
             name: "async_calculator",
             arguments: { x: 5, y: 3, operation: "add" },
             task: { ttl: 60_000 }
           }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    assert body["result"]["task"], "Expected task in result"
    assert body["result"]["task"]["taskId"], "Expected task id"
    assert_equal "working", body["result"]["task"]["status"]
    assert_equal body["result"]["task"]["taskId"],
                 body["result"]["_meta"]["io.modelcontextprotocol/related-task"]["taskId"]

    # Verify task was created in database
    task_id = body["result"]["task"]["taskId"]
    task = @session.tasks.find_by(id: task_id)
    assert task, "Task should exist in database"
    assert_equal "tools/call", task.request_method
    assert_equal "async_calculator", task.request_name
    assert_equal 60_000, task.ttl
    assert_equal task.id, task.request_params["_meta"]["io.modelcontextprotocol/related-task"]["taskId"]
  ensure
    ActionMCP.configuration.tasks_enabled = original_tasks_enabled
  end

  test "tool call without task parameter executes synchronously when tasks enabled" do
    # Enable tasks for this test
    original_tasks_enabled = ActionMCP.configuration.tasks_enabled
    ActionMCP.configuration.tasks_enabled = true

    # Register the async calculator tool
    ActionMCP::ToolsRegistry.register(AsyncCalculatorTool)
    @session.register_tool(AsyncCalculatorTool)
    @session.save!

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "sync-tool-1",
           method: "tools/call",
           params: {
             name: "async_calculator",
             arguments: { x: 10, y: 4, operation: "subtract" }
             # No task parameter - should execute synchronously
           }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    # Sync execution returns content directly, not a task
    assert body["result"]["content"], "Expected content in result for sync execution"
    # Result can be integer (6) or float (6.0) depending on JSON parsing
    assert_match(/Result: 6(\.0)?/, body["result"]["content"].first["text"])
  ensure
    ActionMCP.configuration.tasks_enabled = original_tasks_enabled
  end

  test "tool call with task parameter rejects tools that forbid task execution" do
    original_tasks_enabled = ActionMCP.configuration.tasks_enabled
    ActionMCP.configuration.tasks_enabled = true

    ActionMCP::ToolsRegistry.register(AddTool)
    @session.register_tool(AddTool)
    @session.save!

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "forbidden-task-tool-1",
           method: "tools/call",
           params: {
             name: "add",
             arguments: { a: 1, b: 2 },
             task: { ttl: 60_000 }
           }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert_equal(-32_601, body["error"]["code"])
    assert_match(/does not support task-augmented execution/, body["error"]["message"])
  ensure
    ActionMCP.configuration.tasks_enabled = original_tasks_enabled
  end

  test "tool call without task parameter rejects tools that require task execution" do
    original_tasks_enabled = ActionMCP.configuration.tasks_enabled
    ActionMCP.configuration.tasks_enabled = true

    ActionMCP::ToolsRegistry.register(RequiredTaskDemoTool)
    @session.register_tool(RequiredTaskDemoTool)
    @session.save!

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "required-task-tool-1",
           method: "tools/call",
           params: {
             name: "required_task_demo",
             arguments: {}
           }
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert_equal(-32_601, body["error"]["code"])
    assert_match(/requires task-augmented execution/, body["error"]["message"])
  ensure
    ActionMCP.configuration.tasks_enabled = original_tasks_enabled
  end

  test "tool call with task parameter is rejected when tasks are not negotiated" do
    original_tasks_enabled = ActionMCP.configuration.tasks_enabled
    ActionMCP.configuration.tasks_enabled = true
    old_session = action_mcp_sessions(:dr_identity_mcbouncer_session)

    ActionMCP::ToolsRegistry.register(AsyncCalculatorTool)
    old_session.register_tool(AsyncCalculatorTool)
    old_session.save!

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "old-task-tool-1",
           method: "tools/call",
           params: {
             name: "async_calculator",
             arguments: { x: 1, y: 2, operation: "add" },
             task: { ttl: 60_000 }
           }
         }.to_json,
         headers: old_protocol_headers(old_session.id)

    assert_response :success
    body = response.parsed_body
    assert_equal(-32_601, body["error"]["code"])
    assert_match(/not available/, body["error"]["message"])
  ensure
    ActionMCP.configuration.tasks_enabled = original_tasks_enabled
  end

  # Tool taskSupport metadata tests
  test "tools/list includes execution metadata for tools with task_support" do
    # Register the async calculator tool
    ActionMCP::ToolsRegistry.register(AsyncCalculatorTool)
    @session.register_tool(AsyncCalculatorTool)
    @session.save!

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "tools-list-1",
           method: "tools/list"
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    assert body["result"]["tools"], "Expected tools in result"

    # Find the async_calculator tool
    async_calc = body["result"]["tools"].find { |t| t["name"] == "async_calculator" }
    assert async_calc, "Expected async_calculator tool in list"

    # Should have execution metadata with taskSupport
    assert async_calc["execution"], "Expected execution metadata for tool with task_support"
    assert_equal "optional", async_calc["execution"]["taskSupport"]
  end

  test "tools/list omits execution metadata before 2025-11-25" do
    old_session = action_mcp_sessions(:dr_identity_mcbouncer_session)

    ActionMCP::ToolsRegistry.register(AsyncCalculatorTool)
    old_session.register_tool(AsyncCalculatorTool)
    old_session.save!

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "tools-list-old-protocol",
           method: "tools/list"
         }.to_json,
         headers: old_protocol_headers(old_session.id)

    assert_response :success
    body = response.parsed_body
    async_calc = body["result"]["tools"].find { |t| t["name"] == "async_calculator" }
    assert async_calc, "Expected async_calculator tool in list"
    refute async_calc["execution"], "Execution metadata is only defined for MCP 2025-11-25"
  end

  test "tools/list excludes execution metadata for tools without task_support" do
    # Register a standard tool (AddTool has no task_support set, defaults to :forbidden)
    ActionMCP::ToolsRegistry.register(AddTool)
    @session.register_tool(AddTool)
    @session.save!

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "tools-list-2",
           method: "tools/list"
         }.to_json,
         headers: request_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"]["tools"]

    # Find the add tool
    add_tool = body["result"]["tools"].find { |t| t["name"] == "add" }
    assert add_tool, "Expected add tool in list"

    # Should NOT have execution metadata (default is :forbidden which is omitted)
    refute add_tool["execution"], "Should not have execution metadata for default task_support"
  end

  private

  def request_headers
    {
      "CONTENT_TYPE" => "application/json",
      "ACCEPT" => "application/json, text/event-stream",
      "Mcp-Session-Id" => @session_id,
      "MCP-Protocol-Version" => "2025-11-25"
    }
  end

  def old_protocol_headers(session_id)
    {
      "CONTENT_TYPE" => "application/json",
      "ACCEPT" => "application/json, text/event-stream",
      "Mcp-Session-Id" => session_id,
      "MCP-Protocol-Version" => "2025-06-18"
    }
  end
end

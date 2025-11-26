# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class Session
    class TaskTest < ActiveSupport::TestCase
      setup do
        @session = ActionMCP::Session.create!(
          status: "initialized",
          protocol_version: "2025-11-25",
          client_info: { name: "test", version: "1.0" }
        )
      end

      teardown do
        @session.destroy if @session.persisted?
      end

      test "creates task with UUID id" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        assert task.id.present?
        assert_match(/\A[0-9a-f-]{36}\z/, task.id)
      end

      test "initial status is working" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        assert_equal "working", task.status
      end

      test "sets last_updated_at on create" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        assert task.last_updated_at.present?
      end

      # State machine transitions
      test "can transition from working to completed" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        assert task.complete!
        assert_equal "completed", task.status
      end

      test "can transition from working to failed" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        assert task.mark_failed!
        assert_equal "failed", task.status
      end

      test "can transition from working to cancelled" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        assert task.cancel!
        assert_equal "cancelled", task.status
      end

      test "can transition from working to input_required" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        assert task.require_input!
        assert_equal "input_required", task.status
      end

      test "can resume from input_required to working" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        task.require_input!
        assert task.resume!
        assert_equal "working", task.status
      end

      test "can transition from input_required to completed" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        task.require_input!
        assert task.complete!
        assert_equal "completed", task.status
      end

      # Terminal state checks
      test "terminal? returns true for completed" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        task.complete!
        assert task.terminal?
      end

      test "terminal? returns true for failed" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        task.mark_failed!
        assert task.terminal?
      end

      test "terminal? returns true for cancelled" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        task.cancel!
        assert task.terminal?
      end

      test "terminal? returns false for working" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        refute task.terminal?
      end

      test "non_terminal? is inverse of terminal?" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
        assert task.non_terminal?
        task.complete!
        refute task.non_terminal?
      end

      # TTL/Expiration
      test "expired? returns false when ttl is nil" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool", ttl: nil)
        refute task.expired?
      end

      test "expired? returns false when within ttl" do
        task = @session.tasks.create!(
          request_method: "tools/call",
          request_name: "test_tool",
          ttl: 60_000 # 60 seconds
        )
        refute task.expired?
      end

      # Scopes
      test "with_status scope filters by status" do
        task1 = @session.tasks.create!(request_method: "tools/call", request_name: "tool1")
        task2 = @session.tasks.create!(request_method: "tools/call", request_name: "tool2")
        task2.complete!

        working_tasks = @session.tasks.with_status(:working)
        assert_includes working_tasks, task1
        refute_includes working_tasks, task2
      end

      test "terminal scope returns only terminal tasks" do
        task1 = @session.tasks.create!(request_method: "tools/call", request_name: "tool1")
        task2 = @session.tasks.create!(request_method: "tools/call", request_name: "tool2")
        task2.complete!

        terminal_tasks = @session.tasks.terminal
        refute_includes terminal_tasks, task1
        assert_includes terminal_tasks, task2
      end

      test "non_terminal scope returns only non-terminal tasks" do
        task1 = @session.tasks.create!(request_method: "tools/call", request_name: "tool1")
        task2 = @session.tasks.create!(request_method: "tools/call", request_name: "tool2")
        task2.complete!

        non_terminal_tasks = @session.tasks.non_terminal
        assert_includes non_terminal_tasks, task1
        refute_includes non_terminal_tasks, task2
      end

      # Serialization
      test "to_task_data returns correct format" do
        task = @session.tasks.create!(
          request_method: "tools/call",
          request_name: "test_tool",
          status_message: "Processing"
        )

        data = task.to_task_data
        assert_equal task.id, data[:id]
        assert_equal "working", data[:status]
        assert data[:lastUpdatedAt].present?
        assert_equal "Processing", data[:statusMessage]
      end

      test "to_task_data excludes statusMessage when blank" do
        task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")

        data = task.to_task_data
        refute data.key?(:statusMessage)
      end

      test "to_task_result includes task data and result payload" do
        task = @session.tasks.create!(
          request_method: "tools/call",
          request_name: "test_tool",
          result_payload: { content: [ { type: "text", text: "Result" } ] }
        )
        task.complete!

        result = task.to_task_result
        assert result[:task].present?
        assert result[:result].present?
        assert_equal "Result", result[:result]["content"].first["text"]
      end

      # JSON storage
      test "stores request_params as JSON" do
        params = { name: "test_tool", arguments: { x: 1, y: 2 } }
        task = @session.tasks.create!(
          request_method: "tools/call",
          request_name: "test_tool",
          request_params: params
        )

        task.reload
        assert_equal "test_tool", task.request_params["name"]
        assert_equal({ "x" => 1, "y" => 2 }, task.request_params["arguments"])
      end

      test "stores result_payload as JSON" do
        payload = { content: [ { type: "text", text: "Hello" } ] }
        task = @session.tasks.create!(
          request_method: "tools/call",
          request_name: "test_tool",
          result_payload: payload
        )

        task.reload
        assert_equal "text", task.result_payload["content"].first["type"]
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ToolExecutionJobTest < ActiveSupport::TestCase
    setup do
      @session = Session.create!(
        status: "initialized",
        protocol_version: "2025-11-25",
        client_info: { name: "test", version: "1.0" }
      )
    end

    test "stale job completion cannot transition a cancelled task" do
      task, stale_job_task = create_task_and_stale_copy
      task.cancel!

      apply_job_result(stale_job_task, ToolResponse.new)

      assert_equal "cancelled", task.reload.status
      assert_nil task.result_payload
    end

    test "stale job failure cannot transition a cancelled task" do
      task, stale_job_task = create_task_and_stale_copy
      task.cancel!
      result = ToolResponse.new.tap { |response| response.report_tool_error("failed") }

      apply_job_result(stale_job_task, result)

      assert_equal "cancelled", task.reload.status
      assert_nil task.result_payload
    end

    test "stale invalid input failure cannot transition a cancelled task" do
      task, stale_job_task = create_task_and_stale_copy
      task.cancel!
      invalid_tool_class = Object.new
      invalid_tool_class.define_singleton_method(:tool_name) { "invalid_input" }
      invalid_tool_class.define_singleton_method(:from_wire) { |_| raise ArgumentError, "invalid input" }
      job = ToolExecutionJob.new
      job.instance_variable_set(:@task, stale_job_task)

      @session.stub(:registered_tools, [ invalid_tool_class ]) do
        assert_nil job.send(:prepare_tool, @session, "invalid_input", {}, stale_job_task)
      end

      assert_equal "cancelled", task.reload.status
      assert_nil task.result_payload
    end

    test "stale missing tool failure cannot transition a cancelled task" do
      task, stale_job_task = create_task_and_stale_copy
      task.cancel!

      @session.stub(:registered_tools, []) do
        assert_nil ToolExecutionJob.new.send(:prepare_tool, @session, "missing", {}, stale_job_task)
      end

      assert_equal "cancelled", task.reload.status
      assert_nil task.result_payload
    end

    test "loading a cancelled task does not record job startup" do
      task, = create_task_and_stale_copy
      task.cancel!

      loaded_task = ToolExecutionJob.new.send(:load_task, task.id)

      assert_equal "cancelled", loaded_task.status
      refute_equal "job_started", loaded_task.continuation_state&.fetch("step", nil)
    end

    private

    def create_task_and_stale_copy
      task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
      [ task, Session::Task.find(task.id) ]
    end

    def apply_job_result(task, result)
      ToolExecutionJob.new.send(:update_task_result, task, result)
    end
  end
end

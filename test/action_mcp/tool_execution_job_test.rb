# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ToolExecutionJobTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

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

    test "the job runs with the identity of the request that enqueued it" do
      user = User.create!(email: "tasks@example.com", password: "password", name: "Task Runner")
      task = dispatch_task("deploy")

      Current.set(user: user) { enqueue(task, "deploy") }
      Current.reset
      perform_enqueued_jobs

      assert_equal "completed", task.reload.status
      assert_equal "Dispatched deploy", task.result_payload.dig("content", 0, "text")
    end

    test "an identity ActiveJob cannot serialize stays behind without breaking the enqueue" do
      dev_user = NoneIdentifier.new(nil).resolve
      denied = dispatch_task("deploy")
      allowed = dispatch_task("status")

      Current.set(user: dev_user) do
        enqueue(denied, "deploy")
        enqueue(allowed, "status")
      end
      perform_enqueued_jobs

      assert_equal "failed", denied.reload.status
      assert_equal "completed", allowed.reload.status
    end

    test "resuming a task re-enqueues the original arguments and meta" do
      task = @session.tasks.create!(
        request_method: "tools/call",
        request_name: "dispatch_operation",
        request_params: { name: "dispatch_operation", arguments: { operation: "status" }, _meta: { trace: "t-1" } }
      )
      task.require_input!

      assert_enqueued_with(job: ToolExecutionJob,
                           args: [ task.id, "dispatch_operation", { "operation" => "status" }, { "trace" => "t-1" } ]) do
        task.resume_from_continuation!
      end
    end

    test "an unexpected error fails the task and the job" do
      task = dispatch_task("status")
      enqueue(task, "status")

      DevReloader.stub(:wrap, -> { raise "worker exploded" }) do
        assert_raises(RuntimeError) { perform_enqueued_jobs }
      end

      assert_equal "failed", task.reload.status
      assert_equal "Job failed: worker exploded", task.status_message
    end

    test "a deadlock is retried and the task completes" do
      task = dispatch_task("status")
      enqueue(task, "status")
      attempts = 0
      flaky = lambda do |&run|
        attempts += 1
        raise ActiveRecord::Deadlocked, "deadlock" if attempts == 1

        run.call
      end

      DevReloader.stub(:wrap, flaky) do
        perform_enqueued_jobs
        perform_enqueued_jobs
      end

      assert_equal 2, attempts
      assert_equal "completed", task.reload.status
    end

    test "re-running a job for a failed task leaves it alone" do
      task = dispatch_task("status")
      task.mark_failed!

      ToolExecutionJob.perform_now(task.id, "dispatch_operation", { "operation" => "status" }, {})

      assert_equal "failed", task.reload.status
      assert_nil task.result_payload
    end

    private

    def dispatch_task(operation)
      @session.tasks.create!(
        request_method: "tools/call",
        request_name: "dispatch_operation",
        request_params: { name: "dispatch_operation", arguments: { operation: operation } }
      )
    end

    def enqueue(task, operation)
      ToolExecutionJob.perform_later(task.id, "dispatch_operation", { "operation" => operation }, {})
    end

    def create_task_and_stale_copy
      task = @session.tasks.create!(request_method: "tools/call", request_name: "test_tool")
      [ task, Session::Task.find(task.id) ]
    end

    def apply_job_result(task, result)
      ToolExecutionJob.new.send(:update_task_result, task, result)
    end
  end
end

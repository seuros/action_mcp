# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class TasksTest < ActiveSupport::TestCase
      FakeTask = Struct.new(:status, :payload) do
        def terminal?
          %w[completed failed cancelled].include?(status)
        end

        def to_task_error
          nil
        end

        def to_task_result
          payload
        end
      end

      class TestTransport
        include Tasks

        attr_reader :responses, :sleep_count

        def initialize(initial_task, reloads)
          @initial_task = initial_task
          @reloads = reloads
          @responses = []
          @sleep_count = 0
        end

        def send_jsonrpc_response(id, result: nil, error: nil)
          @responses << { id: id, result: result, error: error }
        end

        private

        def find_task(_task_id)
          @initial_task
        end

        def load_task_for_result(_task_id)
          @reloads.shift
        end

        def sleep(_duration)
          @sleep_count += 1
        end
      end

      test "tasks result waits through input_required until terminal" do
        input_required = FakeTask.new("input_required", { intermediate: true })
        completed = FakeTask.new("completed", { content: [ { type: "text", text: "done" } ] })
        transport = TestTransport.new(input_required, [ input_required, completed ])

        transport.send_tasks_result("request-1", "task-1")

        assert_equal 1, transport.sleep_count
        assert_equal completed.payload, transport.responses.sole[:result]
        assert_nil transport.responses.sole[:error]
      end
    end
  end
end

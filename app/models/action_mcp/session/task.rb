# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "action_mcp_session_tasks"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "string", pk = true, null = false },
#   { name = "created_at", type = "datetime", null = false },
#   { name = "last_updated_at", type = "datetime", null = false },
#   { name = "poll_interval", type = "integer" },
#   { name = "progress_message", type = "string" },
#   { name = "progress_percent", type = "integer" },
#   { name = "request_method", type = "string" },
#   { name = "request_name", type = "string" },
#   { name = "request_params", type = "json" },
#   { name = "result_payload", type = "json" },
#   { name = "session_id", type = "string", null = false },
#   { name = "status", type = "string", null = false, default = "working" },
#   { name = "status_message", type = "string" },
#   { name = "ttl", type = "integer" },
#   { name = "updated_at", type = "datetime", null = false }
# ]
#
# indexes = [
#   { name = "index_action_mcp_session_tasks_on_status", columns = ["status"] },
#   { name = "index_action_mcp_session_tasks_on_session_id", columns = ["session_id"] },
#   { name = "index_action_mcp_session_tasks_on_session_id_and_status", columns = ["session_id", "status"] },
#   { name = "index_action_mcp_session_tasks_on_created_at", columns = ["created_at"] }
# ]
#
# foreign_keys = [
#   { column = "session_id", references_table = "action_mcp_sessions", references_column = "id", on_delete = "cascade", on_update = "cascade" }
# ]
#
# [callbacks]
# before_validation = [{ method = "set_last_updated_at" }]
# around_validation = [{ method = "machine" }]
#
# notes = ["index_action_mcp_session_tasks_on_session_id:REDUND_IDX", "session:COUNTER_CACHE", "poll_interval:NOT_NULL", "progress_message:NOT_NULL", "progress_percent:NOT_NULL", "request_method:NOT_NULL", "request_name:NOT_NULL", "request_params:NOT_NULL", "result_payload:NOT_NULL", "status_message:NOT_NULL", "ttl:NOT_NULL", "status_message:DEFAULT", "id:LIMIT", "progress_message:LIMIT", "request_method:LIMIT", "request_name:LIMIT", "session_id:LIMIT", "status:LIMIT", "status_message:LIMIT", "status_message:INDEX"]
# <rails-lens:schema:end>
require "state_machines-activerecord"

module ActionMCP
  class Session
    # Represents a Task in an MCP session as per MCP 2025-11-25 specification.
    # Tasks provide durable state machines for tracking async request execution.
    #
    # State Machine:
    #   working -> input_required -> working (via resume)
    #   working -> completed | failed | cancelled
    #   input_required -> completed | failed | cancelled
    #
    class Task < ApplicationRecord
      self.table_name = "action_mcp_session_tasks"

      attribute :id, :string, default: -> { SecureRandom.uuid_v7 }

      belongs_to :session, class_name: "ActionMCP::Session", inverse_of: :tasks

      # JSON columns are handled natively by Rails 8.1+
      # No serialize needed for json column types

      # Validations
      validates :status, presence: true
      validates :last_updated_at, presence: true

      # Scopes - state_machines >= 0.100.0 auto-generates .with_status(:state) scopes
      scope :terminal, -> { with_status(:completed, :failed, :cancelled) }
      scope :non_terminal, -> { with_status(:working, :input_required) }
      scope :recent, -> { order(created_at: :desc, id: :desc) }
      scope :before_recent, lambda { |task|
        table = arel_table

        where(
          table[:created_at].lt(task.created_at)
            .or(table[:created_at].eq(task.created_at).and(table[:id].lt(task.id)))
        )
      }

      # State machine definition per MCP spec
      state_machine :status, initial: :working do
        # Terminal states
        state :completed
        state :failed
        state :cancelled

        # Non-terminal states
        state :working
        state :input_required

        # Transition to input_required when awaiting user/client input
        event :require_input do
          transition working: :input_required
        end

        # Resume from input_required back to working
        event :resume do
          transition input_required: :working
        end

        # Complete the task successfully
        event :complete do
          transition %i[working input_required] => :completed
        end

        # Mark the task as failed due to an error
        # Note: Using 'mark_failed' instead of 'fail' to avoid conflict with Object#fail
        event :mark_failed do
          transition %i[working input_required] => :failed
        end

        # Cancel the task
        event :cancel do
          transition %i[working input_required] => :cancelled
        end

        # After any transition, update timestamp and broadcast
        after_transition do |task, transition|
          task.update_column(:last_updated_at, Time.current)
          task.broadcast_status_change(transition)
        end
      end

      # Callbacks
      before_validation :set_last_updated_at, on: :create

      # TTL management
      # @return [Boolean] true if task has exceeded its TTL
      def expired?
        return false if ttl.nil?

        # TTL is stored in milliseconds (MCP spec)
        created_at + (ttl / 1000.0).seconds < Time.current
      end

      # Check if task is in a terminal state
      def terminal?
        status.in?(%w[completed failed cancelled])
      end

      # Check if task is in a non-terminal state
      def non_terminal?
        !terminal?
      end

      # Convert to task data format per MCP spec
      # @return [Hash] Task data for JSON-RPC responses
      def to_task_data
        data = {
          id: id,
          status: status,
          lastUpdatedAt: last_updated_at.iso8601(3)
        }
        data[:statusMessage] = status_message if status_message.present?

        # Add progress if available (ActiveJob::Continuable support)
        if progress_percent.present? || progress_message.present?
          data[:progress] = {}.tap do |progress|
            progress[:percent] = progress_percent if progress_percent.present?
            progress[:message] = progress_message if progress_message.present?
          end
        end

        data
      end

      # Convert to full task result format
      # @return [Hash] Complete task with result for tasks/result response
      def to_task_result
        {
          task: to_task_data,
          result: result_payload
        }
      end

      # Broadcast status change notification to the session
      # @param transition [StateMachines::Transition] The state transition that occurred
      def broadcast_status_change(transition = nil)
        return unless session

        handler = ActionMCP::Server::TransportHandler.new(session)
        handler.send_task_status_notification(self)
      rescue StandardError => e
        Rails.logger.warn "Failed to broadcast task status change: #{e.message}"
      end

      # Continuation State Management (for ActiveJob::Continuable support)

      # Record step execution state for job resumption
      # @param step_name [Symbol] Name of the step
      # @param cursor [Integer, String] Optional cursor for resuming iteration
      # @param data [Hash] Additional step data to persist
      def record_step!(step_name, cursor: nil, data: {})
        update!(
          continuation_state: {
            step: step_name,
            cursor: cursor,
            data: data,
            timestamp: Time.current.iso8601
          },
          last_step_at: Time.current
        )
      end

      # Store partial result fragment (for streaming/incremental results)
      # @param result_fragment [Hash] Partial result to append
      def store_partial_result!(result_fragment)
        payload = result_payload || {}
        payload[:partial] ||= []
        payload[:partial] << result_fragment
        update!(result_payload: payload)
      end

      # Update progress indicators for long-running tasks
      # @param percent [Integer] Progress percentage (0-100)
      # @param message [String] Optional progress message
      def update_progress!(percent:, message: nil)
        update!(
          progress_percent: percent.clamp(0, 100),
          progress_message: message,
          last_step_at: Time.current
        )
      end

      # Transition to input_required state and store pending input prompt
      # @param prompt [String] The prompt/question for the user
      # @param context [Hash] Additional context about the input request
      def await_input!(prompt:, context: {})
        record_step!(:awaiting_input, data: { prompt: prompt, context: context })
        require_input!
      end

      # Resume task from input_required state and re-enqueue job
      # @return [void]
      def resume_from_continuation!
        return unless input_required?

        resume!
        # Re-enqueue the job to continue execution
        ActionMCP::ToolExecutionJob.perform_later(id, request_name, request_params, {})
      end

      private

      def set_last_updated_at
        self.last_updated_at ||= Time.current
      end
    end
  end
end

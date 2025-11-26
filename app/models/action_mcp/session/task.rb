# frozen_string_literal: true

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

      attribute :id, :string, default: -> { SecureRandom.uuid }

      belongs_to :session, class_name: "ActionMCP::Session", inverse_of: :tasks

      # JSON columns are handled natively by Rails 8.1+
      # No serialize needed for json column types

      # Validations
      validates :status, presence: true
      validates :last_updated_at, presence: true

      # Scopes - state_machines >= 0.100.0 auto-generates .with_status(:state) scopes
      scope :terminal, -> { with_status(:completed, :failed, :cancelled) }
      scope :non_terminal, -> { with_status(:working, :input_required) }
      scope :recent, -> { order(created_at: :desc) }

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

      private

      def set_last_updated_at
        self.last_updated_at ||= Time.current
      end
    end
  end
end

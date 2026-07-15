# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class ClientNotificationsTest < ActiveSupport::TestCase
      setup do
        @session = BaseSession.new(
          {
            id: "client-notifications",
            role: "server",
            status: "initialized",
            initialized: true,
            client_capabilities: {}
          }
        )
        @transport = TransportHandler.new(@session, messaging_mode: :return)
        @handler = JsonRpcHandler.new(@transport)
      end

      test "cancellation marks only the matching in-flight request direction and ID type" do
        incoming_integer = @session.read(request(id: 7, method: "tools/list").to_h)
        incoming_string = @session.read(request(id: "7", method: "tools/list").to_h)
        outgoing = @session.write(request(id: 7, method: "sampling/createMessage").to_h)

        event = capture_event("request_cancelled.action_mcp") do
          notify("notifications/cancelled", requestId: 7, reason: "No longer needed")
        end

        assert incoming_integer[:request_cancelled]
        refute incoming_string[:request_cancelled]
        refute outgoing[:request_cancelled]
        assert_same incoming_integer, event.payload[:request]
        assert_equal "No longer needed", event.payload[:params][:reason]
      end

      test "initialize cancellation and late cancellation are ignored" do
        initialize_request = @session.read(request(id: "init", method: "initialize").to_h)

        assert_nil notify("notifications/cancelled", requestId: "init")
        assert_nil notify("notifications/cancelled", requestId: "already-finished")
        refute initialize_request[:request_cancelled]
      end

      test "responses acknowledge only the request issued in the opposite direction" do
        incoming = @session.read(request(id: "shared", method: "tools/list").to_h)
        outgoing = @session.write(
          request(id: "shared", method: "sampling/createMessage", params: sampling_params).to_h
        )

        @handler.call(JSON_RPC::Response.new(id: "shared", result: { model: "test" }))

        refute incoming[:request_acknowledged]
        assert outgoing[:request_acknowledged]
      end

      test "progress is correlated with the server-originated client request" do
        issued = @session.write(
          request(
            id: "sample",
            method: "sampling/createMessage",
            params: sampling_params(_meta: { progressToken: "sample-progress" })
          ).to_h
        )

        event = capture_event("request_progress.action_mcp") do
          notify(
            "notifications/progress",
            progressToken: "sample-progress",
            progress: 2,
            total: 4,
            message: "Halfway"
          )
        end

        assert_same issued, event.payload[:request]
        assert_equal 2, event.payload[:params][:progress]
      end

      test "progress stops correlating after an ordinary request completes" do
        @session.write(
          request(
            id: "sample",
            method: "sampling/createMessage",
            params: sampling_params(_meta: { progressToken: "sample-progress" })
          ).to_h
        )
        @handler.call(JSON_RPC::Response.new(id: "sample", result: { model: "test" }))

        events = capture_events("request_progress.action_mcp") do
          notify("notifications/progress", progressToken: "sample-progress", progress: 3)
        end

        assert_empty events
      end

      test "task status is correlated through the create-task response" do
        issued = @session.write(
          request(
            id: "elicit",
            method: "elicitation/create",
            params: {
              mode: "form",
              message: "Choose",
              requestedSchema: { type: "object", properties: {} },
              task: { ttl: 60_000 },
              _meta: { progressToken: "task-progress" }
            }
          ).to_h
        )
        task = {
          taskId: "client-task",
          status: "working",
          createdAt: "2026-07-15T10:00:00Z",
          lastUpdatedAt: "2026-07-15T10:00:00Z",
          ttl: 60_000
        }
        @handler.call(JSON_RPC::Response.new(id: "elicit", result: { task: task }))

        progress_event = capture_event("request_progress.action_mcp") do
          notify("notifications/progress", progressToken: "task-progress", progress: 1)
        end

        event = capture_event("task_status.action_mcp") do
          notify("notifications/tasks/status", task.merge(status: "completed"))
        end

        late_progress_events = capture_events("request_progress.action_mcp") do
          notify("notifications/progress", progressToken: "task-progress", progress: 2)
        end

        assert issued[:request_acknowledged]
        assert_same issued, progress_event.payload[:request]
        assert_same issued, event.payload[:request]
        assert_equal "completed", event.payload[:params][:status]
        assert_empty late_progress_events
      end

      test "roots list changes persist the generated client request in return mode" do
        @session.client_capabilities = { "roots" => { "listChanged" => true } }

        notify("notifications/roots/list_changed")

        issued = @session.messages.reverse.find do |message|
          payload = message[:data].respond_to?(:to_h) ? message[:data].to_h : message[:data]
          (payload[:method] || payload["method"]) == "roots/list"
        end
        assert issued
        assert_equal "client", issued[:direction]
      end

      private

      def request(id:, method:, params: nil)
        JSON_RPC::Request.new(id: id, method: method, params: params)
      end

      def notify(method, params = nil)
        @handler.call(JSON_RPC::Notification.new(method: method, params: params))
      end

      def sampling_params(_meta: nil)
        params = {
          messages: [ { role: "user", content: { type: "text", text: "Hello" } } ],
          maxTokens: 16
        }
        params[:_meta] = _meta if _meta
        params
      end

      def capture_event(name)
        events = capture_events(name) { yield }
        assert_equal 1, events.size
        events.first
      end

      def capture_events(name)
        events = []
        subscriber = ActiveSupport::Notifications.subscribe(name) do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end
        yield
        events
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end
    end
  end
end

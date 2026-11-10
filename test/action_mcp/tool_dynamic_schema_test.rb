# frozen_string_literal: true

require "test_helper"

class ActionMCP::ToolDynamicSchemaTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "dispatch@example.com", password: "password", name: "Dispatcher")
    ActionMCP::Current.user = @user

    store = ActionMCP::Server.session_store
    @session = store.create_session(nil, { initialized: true, protocol_version: ActionMCP::DEFAULT_PROTOCOL_VERSION })
    @session.session_data = { "labels" => %w[bug feature] }
    store.save_session(@session)
    @transport = ActionMCP::Server::TransportHandler.new(@session, messaging_mode: :return)
  end

  teardown do
    ActionMCP::Current.reset
  end

  test "tools/list resolves procs against the session and current user" do
    properties = listed_schema[:properties]

    assert_equal %w[status deploy rollback], properties["operation"][:enum]
    assert_equal %w[bug feature], properties["labels"][:items][:enum]
    assert_equal 2, properties["labels"][:maxItems]
  end

  test "each user sees their own values" do
    @user.update!(active: false)

    assert_equal %w[status], listed_schema[:properties]["operation"][:enum]
  end

  test "tools/call validates against the caller's values" do
    assert_not call_tool(operation: "deploy")[:isError]
    assert call_tool(operation: "drop_database")[:isError]

    @user.update!(active: false)

    assert call_tool(operation: "deploy")[:isError]
  end

  test "session data feeds collection keywords" do
    assert call_tool(operation: "status", labels: %w[docs])[:isError]

    @session.session_data = { "labels" => %w[bug feature docs] }

    assert_not call_tool(operation: "status", labels: %w[docs])[:isError]
  end

  test "procs fall back when there is no request context" do
    ActionMCP::Current.reset
    properties = DispatchOperationTool.input_schema[:properties]

    assert_equal %w[status], properties["operation"][:enum]
    assert_equal DispatchOperationTool::DEFAULT_LABELS, properties["labels"][:items][:enum]
  end

  test "a failing proc drops only its tool from tools/list and reaches Rails.error" do
    ActionMCP::Current.user = Object.new

    reported = capture_reported_errors do
      @transport.send_tools_list("list-2")
    end
    names = @transport.get_last_response.result[:tools].pluck(:name)

    refute_includes names, "dispatch_operation"
    assert_includes names, "triage_ticket"
    assert_equal [ ActionMCP::SchemaResolutionError ], reported.map(&:class).uniq
    assert_match(/dispatch_operation failed: NoMethodError/, reported.first.message)
  end

  test "a failing proc answers tools/call like an unknown tool" do
    ActionMCP::Current.user = Object.new

    reported = capture_reported_errors do
      @transport.send_tools_call("call-2", "dispatch_operation", { "operation" => "status" })
    end
    error = @transport.get_last_response.error

    assert_equal(-32_602, error[:code])
    assert_match(/not found or not registered/, error[:message])
    assert_equal [ ActionMCP::SchemaResolutionError ], reported.map(&:class)
  end

  test "the stored definition keeps the proc" do
    listed_schema

    assert_kind_of Proc, DispatchOperationTool._schema_properties["operation"][:enum]
  end

  test "only schemas with procs skip the validator cache" do
    assert DispatchOperationTool.dynamic_schema?
    refute TriageTicketTool.dynamic_schema?
    assert_same TriageTicketTool.input_schemer, TriageTicketTool.input_schemer
  end

  private

  def capture_reported_errors
    reported = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) { |error, **| reported << error }
    Rails.error.subscribe(subscriber)
    yield
    reported
  ensure
    Rails.error.unsubscribe(subscriber)
  end

  def listed_schema
    @transport.send_tools_list("list-1")
    tools = @transport.get_last_response.result[:tools]
    tools.find { |tool| tool[:name] == "dispatch_operation" }.fetch(:inputSchema)
  end

  def call_tool(arguments)
    @transport.send_tools_call("call-1", "dispatch_operation", arguments.stringify_keys)
    @transport.get_last_response.result
  end
end

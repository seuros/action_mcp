# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = ActionMCP::Configuration.new
  end

  test "default configuration values" do
    assert_equal true, @config.logging_enabled
    assert_equal true, @config.list_changed
    assert_equal :info, @config.logging_level
    assert_equal false, @config.resources_subscribe
    assert_equal :primary, @config.active_profile
  end

  test "default profiles are loaded" do
    assert @config.profiles.key?(:primary)
    assert @config.profiles.key?(:minimal)

    # Primary profile defaults
    assert_equal [ "all" ], @config.profiles[:primary][:tools]
    assert_equal [ "all" ], @config.profiles[:primary][:prompts]
    assert_equal [ "all" ], @config.profiles[:primary][:resources]

    # Minimal profile defaults
    assert_equal [], @config.profiles[:minimal][:tools]
    assert_equal [], @config.profiles[:minimal][:prompts]
    assert_equal [], @config.profiles[:minimal][:resources]
  end

  test "use_profile switches active profile" do
    @config.use_profile(:minimal)
    assert_equal :minimal, @config.active_profile
  end

  test "use_profile applies profile options" do
    # Create a test profile with specific options
    @config.profiles[:test_profile] = {
      tools: [ "TestTool" ],
      prompts: [],
      resources: [],
      options: {
        list_changed: false,
        logging_enabled: false,
        logging_level: :warn
      }
    }

    @config.use_profile(:test_profile)

    assert_equal false, @config.list_changed
    assert_equal false, @config.logging_enabled
    assert_equal :warn, @config.logging_level
  end

  test "use_profile falls back to primary for non-existent profile" do
    @config.use_profile(:non_existent)
    assert_equal :primary, @config.active_profile
  end

  test "capabilities are generated based on profile content" do
    @config.profiles[:test] = {
      tools: [ "Tool1" ],
      prompts: [ "Prompt1" ],
      resources: [ "Resource1" ],
      options: {
        list_changed: true,
        logging_enabled: true,
        resources_subscribe: true
      }
    }

    @config.use_profile(:test)
    capabilities = @config.capabilities

    assert capabilities[:tools]
    assert_equal true, capabilities[:tools][:listChanged]

    assert capabilities[:prompts]
    assert_equal true, capabilities[:prompts][:listChanged]

    assert capabilities[:resources]
    assert_equal true, capabilities[:resources][:subscribe]
    assert_equal true, capabilities[:resources][:listChanged]

    assert capabilities[:logging]
  end

  test "empty arrays in profile don't generate capabilities" do
    @config.profiles[:empty] = {
      tools: [],
      prompts: [],
      resources: []
    }

    @config.use_profile(:empty)
    capabilities = @config.capabilities

    refute capabilities[:tools]
    refute capabilities[:prompts]
    refute capabilities[:resources]
  end

  test "should_include_all returns true for 'all' value" do
    @config.profiles[:test] = {
      tools: [ "all" ],
      prompts: [ "specific" ],
      resources: []
    }

    @config.use_profile(:test)

    assert @config.send(:should_include_all?, :tools)
    refute @config.send(:should_include_all?, :prompts)
    refute @config.send(:should_include_all?, :resources)
  end

  test "authentication methods default based on environment" do
    # Load profiles to get config from mcp.yml
    @config.load_profiles
    # In test environment
    assert_equal [ "none" ], @config.authentication_methods
  end

  test "gateway class defaults to ApplicationGateway if available" do
    if defined?(::ApplicationGateway)
      assert_equal ::ApplicationGateway, @config.gateway_class
    else
      assert_equal ActionMCP::Gateway, @config.gateway_class
    end
  end

  test "session store defaults based on environment" do
    # In test environment
    assert_equal :volatile, @config.session_store_type
  end

  test "client and server session store types fall back to global type" do
    @config.session_store_type = :active_record

    assert_equal :active_record, @config.client_session_store_type
    assert_equal :active_record, @config.server_session_store_type
  end

  test "client and server session store types can be set independently" do
    @config.client_session_store_type = :volatile
    @config.server_session_store_type = :active_record

    assert_equal :volatile, @config.client_session_store_type
    assert_equal :active_record, @config.server_session_store_type
  end

  test "thread-local profile override" do
    @config.use_profile(:primary)

    # Set thread-local override
    ActionMCP.thread_profiles.value = :minimal

    assert_equal :minimal, @config.active_profile

    # Clean up
    ActionMCP.thread_profiles.value = nil
  end

  test "protocol version defaults" do
    assert_equal "2025-03-26", @config.protocol_version
  end

  test "SSE configuration defaults" do
    assert_equal 30, @config.sse_heartbeat_interval
    assert_equal :json, @config.post_response_preference
    assert_equal 15.minutes, @config.sse_event_retention_period
    assert_equal 100, @config.max_stored_sse_events
  end
end

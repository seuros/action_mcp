# frozen_string_literal: true

require "test_helper"

class ActionMCP::GatewaySecurityTest < ActiveSupport::TestCase
  setup do
    @request = ActionDispatch::Request.new({})
  end

  test "rejects invalid identity keys" do
    gateway = ActionMCP::Gateway.new(@request)

    error = assert_raises(ArgumentError) do
      gateway.send(:assign_identities, { malicious_key: "value" })
    end

    assert_match(/Invalid identity key/, error.message)
    assert_match(/malicious_key/, error.message)
  end

  test "accepts whitelisted identity keys" do
    gateway = ActionMCP::Gateway.new(@request)

    # Should not raise for valid keys
    assert_nothing_raised do
      gateway.send(:assign_identities, { user: "john_doe" })
    end

    assert_equal "john_doe", gateway.user
  end

  test "accepts all whitelisted identity keys" do
    gateway = ActionMCP::Gateway.new(@request)

    # Test all allowed keys
    ActionMCP::Gateway::ALLOWED_IDENTITY_KEYS.each do |key|
      assert_nothing_raised do
        gateway.send(:assign_identities, { key => "test_value" })
      end
    end
  end

  test "prevents method shadowing via dynamic attributes" do
    gateway = ActionMCP::Gateway.new(@request)

    # Attempt to set a dangerous attribute
    error = assert_raises(ArgumentError) do
      gateway.send(:assign_identities, { initialize: "malicious" })
    end

    assert_match(/Invalid identity key/, error.message)
  end

  test "prevents assigning system method names" do
    gateway = ActionMCP::Gateway.new(@request)

    dangerous_keys = %w[object_id class instance_eval instance_exec send public_send]

    dangerous_keys.each do |key|
      error = assert_raises(ArgumentError) do
        gateway.send(:assign_identities, { key => "value" })
      end

      assert_match(/Invalid identity key/, error.message,
                   "Should reject dangerous key: #{key}")
    end
  end

  test "error message includes list of allowed keys" do
    gateway = ActionMCP::Gateway.new(@request)

    error = assert_raises(ArgumentError) do
      gateway.send(:assign_identities, { bad_key: "value" })
    end

    # Verify the error message includes the allowed keys
    assert_match(/Allowed keys:/, error.message)
    ActionMCP::Gateway::ALLOWED_IDENTITY_KEYS.each do |key|
      assert_match(/#{key}/, error.message)
    end
  end

  test "handles symbol and string keys consistently" do
    gateway = ActionMCP::Gateway.new(@request)

    # Test with symbol
    assert_nothing_raised do
      gateway.send(:assign_identities, { user: "john" })
    end

    # Reset gateway
    gateway = ActionMCP::Gateway.new(@request)

    # Test with string (should also work)
    assert_nothing_raised do
      gateway.send(:assign_identities, { "user" => "jane" })
    end
  end

  test "validates multiple identity keys in one call" do
    gateway = ActionMCP::Gateway.new(@request)

    # Valid keys should work
    assert_nothing_raised do
      gateway.send(:assign_identities, { user: "john", api_key: "key123" })
    end

    assert_equal "john", gateway.user
    assert_equal "key123", gateway.api_key
  end

  test "rejects if any identity key is invalid" do
    gateway = ActionMCP::Gateway.new(@request)

    # One valid, one invalid
    error = assert_raises(ArgumentError) do
      gateway.send(:assign_identities, { user: "john", bad_key: "value" })
    end

    assert_match(/Invalid identity key/, error.message)
    assert_match(/bad_key/, error.message)
  end
end

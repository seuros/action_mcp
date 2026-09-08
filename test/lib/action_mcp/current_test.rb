# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class CurrentTest < ActiveSupport::TestCase
    teardown do
      ActionMCP::Current.reset
    end

    test "session_data defaults to an empty hash" do
      assert_equal({}, ActionMCP::Current.session_data)
    end

    test "session_data is memoized so mutations persist" do
      ActionMCP::Current.session_data[:tenant_id] = 42

      assert_equal 42, ActionMCP::Current.session_data[:tenant_id]
    end

    test "session_data can be assigned directly" do
      ActionMCP::Current.session_data = { locale: "fr" }

      assert_equal({ locale: "fr" }, ActionMCP::Current.session_data)
    end

    test "session_data resets between requests" do
      ActionMCP::Current.session_data[:tenant_id] = 42
      ActionMCP::Current.reset

      assert_equal({}, ActionMCP::Current.session_data)
    end
  end
end

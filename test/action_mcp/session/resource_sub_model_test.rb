# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class SessionSubscriptionModelTest < ActiveSupport::TestCase
    setup { @session = Session.create! }

    test "subscription timestamping" do
      sub = @session.subscriptions.create!(uri: "foo://bar")
      assert_nil sub.last_notification_at

      sub.update!(last_notification_at: Time.current)
      assert sub.last_notification_at.present?
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class SessionResourceSubModelTest < ActiveSupport::TestCase
    setup { @session = Session.create! }

    test "resource touch last_accessed_at helper" do
      res = @session.resources.create!(uri: "foo://bar", mime_type: "text/plain")
      assert_nil res.last_accessed_at

      res.touch(:last_accessed_at)
      assert res.last_accessed_at <= Time.current
    end

    test "subscription timestamping" do
      sub = @session.subscriptions.create!(uri: "foo://bar")
      assert_nil sub.last_notification_at

      sub.update!(last_notification_at: Time.current)
      assert sub.last_notification_at.present?
    end
  end
end

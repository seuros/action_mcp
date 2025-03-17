# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_session_subscriptions
#
#  id                   :bigint           not null, primary key
#  last_notification_at :datetime
#  uri                  :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  session_id           :string           not null
#
# Indexes
#
#  index_action_mcp_session_subscriptions_on_session_id  (session_id)
#
# Foreign Keys
#
#  fk_rails_...  (session_id => action_mcp_sessions.id) ON DELETE => cascade
#
require "test_helper"

module ActionMCP
  class Session
    class SubscriptionTest < ActiveSupport::TestCase
    end
  end
end

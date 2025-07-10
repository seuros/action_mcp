# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_session_subscriptions
#
#  id                   :integer          not null, primary key
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
#  session_id  (session_id => action_mcp_sessions.id) ON DELETE => cascade
#
module ActionMCP
  class Session
    #
    # Represents a client's subscription to a resource for real-time updates.
    # Its role is to store the URI of the resource being subscribed to and track the last time a notification was sent for the subscription.
    # All Subscriptions are deleted when the session is closed.
    class Subscription < ApplicationRecord
      belongs_to :session,
                 class_name: "ActionMCP::Session",
                 inverse_of: :subscriptions
    end
  end
end

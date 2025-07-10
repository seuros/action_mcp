# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_session_resources
#
#  id               :integer          not null, primary key
#  created_by_tool  :boolean          default(FALSE)
#  description      :text
#  last_accessed_at :datetime
#  metadata         :json
#  mime_type        :string           not null
#  name             :string
#  uri              :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  session_id       :string           not null
#
# Indexes
#
#  index_action_mcp_session_resources_on_session_id  (session_id)
#
# Foreign Keys
#
#  session_id  (session_id => action_mcp_sessions.id) ON DELETE => cascade
#
require "test_helper"

module ActionMCP
  class Session
    class ResourceTest < ActiveSupport::TestCase
      # test "the truth" do
      #   assert true
      # end
    end
  end
end

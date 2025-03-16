# == Schema Information
#
# Table name: action_mcp_session_resources
#
#  id               :bigint           not null, primary key
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
#  fk_rails_...  (session_id => action_mcp_sessions.id) ON DELETE => cascade
#
module ActionMCP
  ##
  # Represents a resource associated with an MCP session.
  # Its role is to store information about a resource, such as its URI, MIME type, description,
  # and any associated metadata. It also tracks whether the resource was created by a tool and the last time it was accessed.
  class Session::Resource < ApplicationRecord
    belongs_to :session
  end
end

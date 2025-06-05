# frozen_string_literal: true

class UserInfoTool < ApplicationMCPTool
  tool_name "user_info"
  description "Get information about the current user"

  property :include_email, type: "boolean", required: false, default: false

  def perform
    user = current_user

    if user
      info = { id: user.id }
      info[:email] = user.email if include_email

      render text: "User info: #{info.to_json}"
    else
      render text: "No authenticated user"
    end
  end
end

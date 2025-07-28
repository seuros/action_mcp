# frozen_string_literal: true

class UserInfoTool < ApplicationMCPTool
  tool_name "user_info"
  description "Get detailed information about the currently authenticated user via Gateway"

  property :include_sensitive, type: "boolean", required: false, default: false
  property :include_auth_details, type: "boolean", required: false, default: false

  def perform
    user = current_user

    if user
      info = {
        id: user.id,
        name: user.name,
        email: user.email,
        active: user.active,
        last_login_at: user.last_login_at&.iso8601
      }

      if include_sensitive
        info[:api_key] = user.api_key
        info[:password_digest_present] = user.password_digest.present?
      end

      if include_auth_details
        info[:authentication_type] = detect_authentication_type
        info[:created_at] = user.created_at.iso8601
        info[:updated_at] = user.updated_at.iso8601
      end

      render text: "Authenticated user details:\n#{JSON.pretty_generate(info)}"
    else
      render text: "No authenticated user found. Available authentication methods:\n" \
                   "- Session-based (cookie with user_id)\n" \
                   "- Bearer token (Authorization: Bearer <api_key>)\n" \
                   "- API key (X-API-Key: <api_key>)\n" \
                   "- Custom header (X-User-Email + X-Auth-Token)"
    end
  end

  private

  def detect_authentication_type
    # Access request through the current gateway if available
    gateway = current_gateway
    return "unknown" unless gateway

    begin
      request = gateway.instance_variable_get(:@request)
      return "unknown" unless request&.respond_to?(:headers)

      if request.headers["Authorization"]&.start_with?("Bearer ")
        "bearer_token"
      elsif request.headers["X-API-Key"].present?
        "api_key"
      elsif request.headers["X-User-Email"].present?
        "custom_header"
      elsif request.respond_to?(:session) && request.session[:user_id].present?
        "session"
      else
        "unknown"
      end
    rescue => e
      Rails.logger.debug "Failed to detect authentication type: #{e.message}"
      "unknown"
    end
  end
end

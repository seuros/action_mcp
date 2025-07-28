# frozen_string_literal: true

class AuthenticationDemoTool < ApplicationMCPTool
  tool_name "authentication_demo"
  description "Demonstrates Gateway authentication patterns with examples"

  property :show_examples, type: "boolean", required: false, default: true

  def perform
    user = current_user
    auth_type = detect_authentication_type

    result = []

    if user
      result << "✅ Authentication successful!"
      result << "User: #{user.name} (#{user.email})"
      result << "Auth method: #{auth_type}"
      result << "Last login: #{user.last_login_at&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"
    else
      result << "❌ No authentication found"
    end

    if show_examples
      result << ""
      result << "📚 Authentication Examples:"
      result << ""

      if User.any?
        sample_user = User.first

        result << "1. Session-based (web apps):"
        result << "   curl -X POST http://localhost:62770/sessions \\"
        result << "        -H 'Content-Type: application/json' \\"
        result << "        -d '{\"email\":\"#{sample_user.email}\",\"password\":\"your_password\"}' \\"
        result << "        -c cookies.txt"
        result << "   # Then use -b cookies.txt in subsequent requests"
        result << ""

        result << "2. Bearer token:"
        result << "   Authorization: Bearer #{sample_user.api_key}"
        result << ""

        result << "3. API key:"
        result << "   X-API-Key: #{sample_user.api_key}"
        result << ""

        result << "4. Custom header:"
        expected_token = Digest::SHA256.hexdigest("#{sample_user.email}:#{sample_user.api_key}")
        result << "   X-User-Email: #{sample_user.email}"
        result << "   X-Auth-Token: #{expected_token}"
      else
        result << "No users found. Create a user first:"
        result << "curl -X POST http://localhost:62770/users \\"
        result << "     -H 'Content-Type: application/json' \\"
        result << "     -d '{\"user\":{\"name\":\"Test User\",\"email\":\"test@example.com\",\"password\":\"password\",\"password_confirmation\":\"password\"}}'"
      end
    end

    render text: result.join("\n")
  end

  private

  def detect_authentication_type
    if request.headers["Authorization"]&.start_with?("Bearer ")
      "Bearer Token"
    elsif request.headers["X-API-Key"].present?
      "API Key"
    elsif request.headers["X-User-Email"].present?
      "Custom Header"
    elsif request.session[:user_id].present?
      "Session Cookie"
    else
      "None"
    end
  end
end

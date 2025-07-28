# frozen_string_literal: true

namespace :jwt do
  desc "Generate JWT token for testing (expires 2030)"
  task generate: :environment do
    require_relative "../jwt_fixtures"

    token = JwtFixtures.valid_token

    puts "JWT Token (expires 2030-01-01):"
    puts token
    puts ""
    puts "Test this with curl:"
    puts "curl -X POST http://localhost:62770/ \\"
    puts "  -H \"Content-Type: application/json\" \\"
    puts "  -H \"Accept: application/json\" \\"
    puts "  -H \"Authorization: Bearer #{token}\" \\"
    puts "  -H \"MCP-Protocol-Version: 2025-06-18\" \\"
    puts "  -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}'"
    puts ""

    # Save to file for easy access
    File.write(Rails.root.join("tmp", "jwt_token.txt"), token)
    puts "Token saved to: tmp/jwt_token.txt"
  end

  desc "Show JWT token payload"
  task decode: :environment do
    require_relative "../jwt_fixtures"

    token = JwtFixtures.valid_token
    payload = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: "HS256" })[0]

    puts "JWT Payload:"
    puts JSON.pretty_generate(payload)
  end
end

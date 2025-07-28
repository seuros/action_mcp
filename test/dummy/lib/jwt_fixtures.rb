# frozen_string_literal: true

# JWT fixture generator for testing
class JwtFixtures
  def self.generate_token(user_id: 1, expires_at: nil)
    expires_at ||= Time.new(2030, 1, 1).to_i # January 1, 2030

    payload = {
      user_id: user_id,
      email: "test@example.com",
      name: "Test User",
      iat: Time.current.to_i,
      exp: expires_at
    }

    JWT.encode(payload, Rails.application.secret_key_base, "HS256")
  end

  def self.valid_token
    @valid_token ||= generate_token(user_id: 1)
  end

  def self.expired_token
    @expired_token ||= generate_token(user_id: 1, expires_at: 1.day.ago.to_i)
  end

  def self.invalid_user_token
    @invalid_user_token ||= generate_token(user_id: 99999)
  end
end

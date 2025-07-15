# frozen_string_literal: true

module ActionMCP
  # == Schema Information
  #
  # Table name: action_mcp_oauth_tokens
  #
  #  id                    :integer          not null, primary key
  #  access_token          :string
  #  code_challenge        :string
  #  code_challenge_method :string
  #  expires_at            :datetime
  #  metadata              :json
  #  redirect_uri          :string
  #  revoked               :boolean          default(FALSE)
  #  scope                 :text
  #  token                 :string           not null
  #  token_type            :string           not null
  #  created_at            :datetime         not null
  #  updated_at            :datetime         not null
  #  client_id             :string           not null
  #  user_id               :string
  #
  # Indexes
  #
  #  index_action_mcp_oauth_tokens_on_client_id                  (client_id)
  #  index_action_mcp_oauth_tokens_on_expires_at                 (expires_at)
  #  index_action_mcp_oauth_tokens_on_revoked                    (revoked)
  #  index_action_mcp_oauth_tokens_on_token                      (token) UNIQUE
  #  index_action_mcp_oauth_tokens_on_token_type                 (token_type)
  #  index_action_mcp_oauth_tokens_on_token_type_and_expires_at  (token_type,expires_at)
  #  index_action_mcp_oauth_tokens_on_user_id                    (user_id)
  #
  # OAuth 2.0 Token model for storing access tokens, refresh tokens, and authorization codes
  class OAuthToken < ApplicationRecord
    self.table_name = "action_mcp_oauth_tokens"

    # Token types
    ACCESS_TOKEN = "access_token"
    REFRESH_TOKEN = "refresh_token"
    AUTHORIZATION_CODE = "authorization_code"

    # Validations
    validates :token, presence: true, uniqueness: true
    validates :token_type, presence: true, inclusion: { in: [ ACCESS_TOKEN, REFRESH_TOKEN, AUTHORIZATION_CODE ] }
    validates :client_id, presence: true
    validates :expires_at, presence: true

    # Scopes
    scope :active, -> { where(revoked: false).where("expires_at > ?", Time.current) }
    scope :expired, -> { where("expires_at <= ?", Time.current) }
    scope :access_tokens, -> { where(token_type: ACCESS_TOKEN) }
    scope :refresh_tokens, -> { where(token_type: REFRESH_TOKEN) }
    scope :authorization_codes, -> { where(token_type: AUTHORIZATION_CODE) }

    # Check if token is still valid
    def still_valid?
      !revoked? && !expired?
    end

    # Check if token is expired
    def expired?
      expires_at <= Time.current
    end

    # Revoke the token
    def revoke!
      update!(revoked: true)
    end

    # Convert to introspection response
    def to_introspection_response
      if still_valid?
        {
          active: true,
          scope: scope,
          client_id: client_id,
          username: user_id,
          token_type: token_type == ACCESS_TOKEN ? "Bearer" : token_type,
          exp: expires_at.to_i,
          iat: created_at.to_i,
          nbf: created_at.to_i,
          sub: user_id,
          aud: client_id,
          iss: ActionMCP.configuration.oauth_config&.dig("issuer_url")
        }.compact
      else
        { active: false }
      end
    end

    # Create authorization code
    def self.create_authorization_code(client_id:, user_id:, redirect_uri:, scope:, code_challenge: nil,
                                       code_challenge_method: nil)
      create!(
        token: SecureRandom.urlsafe_base64(32),
        token_type: AUTHORIZATION_CODE,
        client_id: client_id,
        user_id: user_id,
        redirect_uri: redirect_uri,
        scope: scope,
        code_challenge: code_challenge,
        code_challenge_method: code_challenge_method,
        expires_at: 10.minutes.from_now
      )
    end

    # Create access token
    def self.create_access_token(client_id:, user_id:, scope:)
      expires_in = ActionMCP.configuration.oauth_config&.dig("access_token_expires_in") || 3600

      create!(
        token: SecureRandom.urlsafe_base64(32),
        token_type: ACCESS_TOKEN,
        client_id: client_id,
        user_id: user_id,
        scope: scope,
        expires_at: expires_in.seconds.from_now
      )
    end

    # Create refresh token
    def self.create_refresh_token(client_id:, user_id:, scope:, access_token:)
      expires_in = ActionMCP.configuration.oauth_config&.dig("refresh_token_expires_in") || 7.days.to_i

      create!(
        token: SecureRandom.urlsafe_base64(32),
        token_type: REFRESH_TOKEN,
        client_id: client_id,
        user_id: user_id,
        scope: scope,
        access_token: access_token,
        expires_at: expires_in.seconds.from_now
      )
    end

    # Clean up expired tokens
    def self.cleanup_expired
      expired.delete_all
    end
  end
end

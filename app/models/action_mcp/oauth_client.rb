# frozen_string_literal: true

module ActionMCP
  # OAuth 2.0 Client model for storing registered clients
  # == Schema Information
  #
  # Table name: action_mcp_oauth_clients
  #
  #  id                         :integer          not null, primary key
  #  active                     :boolean          default(TRUE)
  #  client_id_issued_at        :integer
  #  client_name                :string
  #  client_secret              :string
  #  client_secret_expires_at   :integer
  #  grant_types                :json
  #  metadata                   :json
  #  redirect_uris              :json
  #  registration_access_token  :string
  #  response_types             :json
  #  scope                      :text
  #  token_endpoint_auth_method :string           default("client_secret_basic")
  #  created_at                 :datetime         not null
  #  updated_at                 :datetime         not null
  #  client_id                  :string           not null
  #
  # Indexes
  #
  #  index_action_mcp_oauth_clients_on_active               (active)
  #  index_action_mcp_oauth_clients_on_client_id            (client_id) UNIQUE
  #  index_action_mcp_oauth_clients_on_client_id_issued_at  (client_id_issued_at)
  #
  # Implements RFC 7591 Dynamic Client Registration
  class OAuthClient < ApplicationRecord
    self.table_name = "action_mcp_oauth_clients"

    # Validations
    validates :client_id, presence: true, uniqueness: true
    validates :token_endpoint_auth_method, inclusion: {
      in: %w[none client_secret_basic client_secret_post client_secret_jwt private_key_jwt]
    }

    # Scopes
    scope :active, -> { where(active: true) }
    scope :expired, -> { where("client_secret_expires_at < ?", Time.current.to_i).where.not(client_secret_expires_at: [ nil, 0 ]) }

    # Callbacks
    before_create :set_issued_at

    # Check if client secret is expired
    def secret_expired?
      return false if client_secret_expires_at.nil? || client_secret_expires_at == 0
      Time.current.to_i > client_secret_expires_at
    end

    # Check if client is public (no authentication required)
    def public_client?
      token_endpoint_auth_method == "none"
    end

    # Check if client is confidential (authentication required)
    def confidential_client?
      !public_client?
    end

    # Validate redirect URI against registered URIs
    def valid_redirect_uri?(uri)
      return false if redirect_uris.blank?
      redirect_uris.include?(uri)
    end

    # Check if grant type is supported by this client
    def supports_grant_type?(grant_type)
      grant_types.include?(grant_type)
    end

    # Check if response type is supported by this client
    def supports_response_type?(response_type)
      response_types.include?(response_type)
    end

    # Check if scope is allowed for this client
    def valid_scope?(requested_scope)
      return true if scope.blank? # No scope restrictions

      requested_scopes = requested_scope.split(" ")
      allowed_scopes = scope.split(" ")

      # All requested scopes must be in allowed scopes
      (requested_scopes - allowed_scopes).empty?
    end

    # Convert to hash for API responses
    def to_api_response
      response = {
        client_id: client_id,
        client_id_issued_at: client_id_issued_at
      }

      # Include client secret for confidential clients
      if client_secret.present?
        response[:client_secret] = client_secret
        response[:client_secret_expires_at] = client_secret_expires_at || 0
      end

      # Include metadata fields
      %w[
        client_name redirect_uris grant_types response_types
        token_endpoint_auth_method scope
      ].each do |field|
        value = send(field)
        response[field.to_sym] = value if value.present?
      end

      # Include additional metadata
      response.merge!(metadata) if metadata.present?

      response
    end

    # Create from registration request
    def self.create_from_registration(client_metadata)
      client = new

      # Set basic fields
      client.client_id = "mcp_#{SecureRandom.hex(16)}"

      # Set metadata fields
      %w[
        client_name redirect_uris grant_types response_types
        token_endpoint_auth_method scope
      ].each do |field|
        client.send("#{field}=", client_metadata[field]) if client_metadata[field]
      end

      # Generate client secret for confidential clients
      if client.confidential_client?
        client.client_secret = SecureRandom.urlsafe_base64(32)
      end

      # Store any additional metadata
      known_fields = %w[
        client_name redirect_uris grant_types response_types
        token_endpoint_auth_method scope
      ]
      additional_metadata = client_metadata.except(*known_fields)
      client.metadata = additional_metadata if additional_metadata.present?

      client
    end

    private

    def set_issued_at
      self.client_id_issued_at ||= Time.current.to_i
    end
  end
end

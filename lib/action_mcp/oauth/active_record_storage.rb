# frozen_string_literal: true

module ActionMCP
  module OAuth
    # ActiveRecord storage for OAuth tokens and codes
    # This is suitable for production multi-server environments
    class ActiveRecordStorage
      # Authorization code storage
      def store_authorization_code(code, data)
        OAuthToken.create!(
          token: code,
          token_type: OAuthToken::AUTHORIZATION_CODE,
          client_id: data[:client_id],
          user_id: data[:user_id],
          redirect_uri: data[:redirect_uri],
          scope: data[:scope],
          code_challenge: data[:code_challenge],
          code_challenge_method: data[:code_challenge_method],
          expires_at: data[:expires_at],
          metadata: data.except(:client_id, :user_id, :redirect_uri, :scope,
                                :code_challenge, :code_challenge_method, :expires_at)
        )
      end

      def retrieve_authorization_code(code)
        token = OAuthToken.authorization_codes.active.find_by(token: code)
        return nil unless token

        {
          client_id: token.client_id,
          user_id: token.user_id,
          redirect_uri: token.redirect_uri,
          scope: token.scope,
          code_challenge: token.code_challenge,
          code_challenge_method: token.code_challenge_method,
          expires_at: token.expires_at,
          created_at: token.created_at
        }.merge(token.metadata || {})
      end

      def remove_authorization_code(code)
        OAuthToken.authorization_codes.where(token: code).destroy_all
      end

      # Access token storage
      def store_access_token(token, data)
        OAuthToken.create!(
          token: token,
          token_type: OAuthToken::ACCESS_TOKEN,
          client_id: data[:client_id],
          user_id: data[:user_id],
          scope: data[:scope],
          expires_at: data[:expires_at],
          metadata: data.except(:client_id, :user_id, :scope, :expires_at)
        )
      end

      def retrieve_access_token(token)
        token_record = OAuthToken.access_tokens.find_by(token: token)
        return nil unless token_record

        {
          client_id: token_record.client_id,
          user_id: token_record.user_id,
          scope: token_record.scope,
          expires_at: token_record.expires_at,
          created_at: token_record.created_at,
          active: token_record.still_valid?
        }.merge(token_record.metadata || {})
      end

      def remove_access_token(token)
        OAuthToken.access_tokens.where(token: token).destroy_all
      end

      # Refresh token storage
      def store_refresh_token(token, data)
        OAuthToken.create!(
          token: token,
          token_type: OAuthToken::REFRESH_TOKEN,
          client_id: data[:client_id],
          user_id: data[:user_id],
          scope: data[:scope],
          access_token: data[:access_token],
          expires_at: data[:expires_at],
          metadata: data.except(:client_id, :user_id, :scope, :access_token, :expires_at)
        )
      end

      def retrieve_refresh_token(token)
        token_record = OAuthToken.refresh_tokens.active.find_by(token: token)
        return nil unless token_record

        {
          client_id: token_record.client_id,
          user_id: token_record.user_id,
          scope: token_record.scope,
          access_token: token_record.access_token,
          expires_at: token_record.expires_at,
          created_at: token_record.created_at
        }.merge(token_record.metadata || {})
      end

      def update_refresh_token(token, new_access_token)
        token_record = OAuthToken.refresh_tokens.find_by(token: token)
        token_record&.update!(access_token: new_access_token)
      end

      def remove_refresh_token(token)
        OAuthToken.refresh_tokens.where(token: token).destroy_all
      end

      # Client registration storage
      def store_client_registration(client_id, data)
        client = OAuthClient.new

        # Map data fields to model attributes
        client.client_id = client_id
        client.client_secret = data[:client_secret]
        client.client_id_issued_at = data[:client_id_issued_at]
        client.registration_access_token = data[:registration_access_token]

        # Handle client metadata
        metadata = data[:client_metadata] || {}
        %w[
          client_name redirect_uris grant_types response_types
          token_endpoint_auth_method scope
        ].each do |field|
          client.send("#{field}=", metadata[field]) if metadata.key?(field)
        end

        # Store any additional metadata
        known_fields = %w[
          client_name redirect_uris grant_types response_types
          token_endpoint_auth_method scope
        ]
        additional_metadata = metadata.except(*known_fields)
        client.metadata = additional_metadata if additional_metadata.present?

        client.save!
        data
      end

      def retrieve_client_registration(client_id)
        client = OAuthClient.active.find_by(client_id: client_id)
        return nil unless client

        {
          client_id: client.client_id,
          client_secret: client.client_secret,
          client_id_issued_at: client.client_id_issued_at,
          registration_access_token: client.registration_access_token,
          client_metadata: client.to_api_response
        }
      end

      def remove_client_registration(client_id)
        OAuthClient.where(client_id: client_id).destroy_all
      end

      # Cleanup expired tokens
      def cleanup_expired
        OAuthToken.cleanup_expired
      end

      # Statistics (for debugging/monitoring)
      def stats
        {
          authorization_codes: OAuthToken.authorization_codes.active.count,
          access_tokens: OAuthToken.access_tokens.active.count,
          refresh_tokens: OAuthToken.refresh_tokens.active.count,
          client_registrations: OAuthClient.active.count
        }
      end

      # Clear all data (for testing)
      def clear_all
        OAuthToken.delete_all
        OAuthClient.delete_all
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  module OAuth
    # In-memory storage for OAuth tokens and codes
    # This is suitable for development and testing, but not for production
    class MemoryStorage
      def initialize
        @authorization_codes = {}
        @access_tokens = {}
        @refresh_tokens = {}
        @client_registrations = {}
        @mutex = Mutex.new
      end

      # Authorization code storage
      def store_authorization_code(code, data)
        @mutex.synchronize do
          @authorization_codes[code] = data
        end
      end

      def retrieve_authorization_code(code)
        @mutex.synchronize do
          @authorization_codes[code]
        end
      end

      def remove_authorization_code(code)
        @mutex.synchronize do
          @authorization_codes.delete(code)
        end
      end

      # Access token storage
      def store_access_token(token, data)
        @mutex.synchronize do
          @access_tokens[token] = data
        end
      end

      def retrieve_access_token(token)
        @mutex.synchronize do
          @access_tokens[token]
        end
      end

      def remove_access_token(token)
        @mutex.synchronize do
          @access_tokens.delete(token)
        end
      end

      # Refresh token storage
      def store_refresh_token(token, data)
        @mutex.synchronize do
          @refresh_tokens[token] = data
        end
      end

      def retrieve_refresh_token(token)
        @mutex.synchronize do
          @refresh_tokens[token]
        end
      end

      def update_refresh_token(token, new_access_token)
        @mutex.synchronize do
          if @refresh_tokens[token]
            @refresh_tokens[token][:access_token] = new_access_token
          end
        end
      end

      def remove_refresh_token(token)
        @mutex.synchronize do
          @refresh_tokens.delete(token)
        end
      end

      # Client registration storage
      def store_client_registration(client_id, data)
        @mutex.synchronize do
          @client_registrations[client_id] = data
        end
      end

      def retrieve_client_registration(client_id)
        @mutex.synchronize do
          @client_registrations[client_id]
        end
      end

      def remove_client_registration(client_id)
        @mutex.synchronize do
          @client_registrations.delete(client_id)
        end
      end

      # Cleanup expired tokens (optional utility method)
      def cleanup_expired
        current_time = Time.current

        @mutex.synchronize do
          @authorization_codes.reject! { |_, data| data[:expires_at] < current_time }
          @access_tokens.reject! { |_, data| data[:expires_at] < current_time }
          @refresh_tokens.reject! { |_, data| data[:expires_at] < current_time }
        end
      end

      # Statistics (for debugging/monitoring)
      def stats
        @mutex.synchronize do
          {
            authorization_codes: @authorization_codes.size,
            access_tokens: @access_tokens.size,
            refresh_tokens: @refresh_tokens.size,
            client_registrations: @client_registrations.size
          }
        end
      end

      # Clear all data (for testing)
      def clear_all
        @mutex.synchronize do
          @authorization_codes.clear
          @access_tokens.clear
          @refresh_tokens.clear
          @client_registrations.clear
        end
      end
    end
  end
end

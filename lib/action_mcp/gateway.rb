# frozen_string_literal: true

module ActionMCP
  class UnauthorizedError < StandardError; end

  class Gateway
    class << self
      def identified_by(*attrs)
        @identifiers ||= []
        @identifiers.concat(attrs.map(&:to_sym)).uniq!
        attr_accessor(*attrs)
      end

      def identifiers
        @identifiers ||= []
      end
    end

    identified_by :user

    attr_reader :request

    def call(request)
      @request = request
      connect
      self
    end

    def connect
      identities = authenticate!
      reject_unauthorized_connection unless identities.is_a?(Hash)

      # Assign all identities (e.g., :user, :account)
      self.class.identifiers.each do |id|
        value = identities[id]
        reject_unauthorized_connection unless value

        public_send("#{id}=", value)

        # Set to ActionMCP::Current
        ActionMCP::Current.public_send("#{id}=", value)
      end

      # Also set the gateway instance itself
      ActionMCP::Current.gateway = self
    end


    protected

    def authenticate!
      auth_methods = ActionMCP.configuration.authentication_methods || [ "jwt" ]

      auth_methods.each do |method|
        case method
        when "none"
          return default_user_identity
        when "jwt"
          result = jwt_authenticate
          return result if result
        when "oauth"
          result = oauth_authenticate
          return result if result
        end
      end

      raise UnauthorizedError, "No valid authentication found"
    end

    def extract_bearer_token
      header = request.headers["Authorization"] || request.headers["authorization"]
      return nil unless header&.start_with?("Bearer ")
      header.split(" ", 2).last
    end

    def resolve_user(payload)
      return nil unless payload.is_a?(Hash)
      user_id = payload["user_id"] || payload["sub"]
      return nil unless user_id
      user = User.find_by(id: user_id)
      return nil unless user

      # Return a hash with all identified_by attributes
      self.class.identifiers.each_with_object({}) do |identifier, hash|
        hash[identifier] = user if identifier == :user
        # Add support for other identifiers as needed
      end
    end

    def reject_unauthorized_connection
      raise UnauthorizedError, "Unauthorized"
    end

    # Default user identity for "none" authentication
    def default_user_identity
      # Return a hash with all identified_by attributes set to a default user
      self.class.identifiers.each_with_object({}) do |identifier, hash|
        if identifier == :user
          # Create or find a default user for development
          hash[identifier] = find_or_create_default_user
        end
        # Add support for other identifiers as needed
      end
    end

    # JWT authentication (existing implementation)
    def jwt_authenticate
      token = extract_bearer_token
      unless token
        raise UnauthorizedError, "Missing token" if ActionMCP.configuration.authentication_methods == [ "jwt" ]
        return nil
      end

      payload = ActionMCP::JwtDecoder.decode(token)
      result = resolve_user(payload)
      unless result
        raise UnauthorizedError, "Unauthorized" if ActionMCP.configuration.authentication_methods == [ "jwt" ]
        return nil
      end
      result
    rescue ActionMCP::JwtDecoder::DecodeError => e
      if ActionMCP.configuration.authentication_methods == [ "jwt" ]
        raise UnauthorizedError, "Invalid token"
      else
        nil # Let it try other authentication methods
      end
    end

    # OAuth authentication via middleware
    def oauth_authenticate
      return nil unless oauth_enabled?

      # Check if OAuth middleware has already validated the token
      token_info = request.env["action_mcp.oauth_token_info"]
      return nil unless token_info && token_info["active"]

      resolve_user_from_oauth(token_info)
    rescue ActionMCP::OAuth::Error
      nil # Let it try other authentication methods
    end

    def oauth_enabled?
      ActionMCP.configuration.authentication_methods&.include?("oauth") &&
        ActionMCP.configuration.oauth_config.present?
    end

    def resolve_user_from_oauth(token_info)
      return nil unless token_info.is_a?(Hash)

      user_id = token_info["sub"] || token_info["user_id"]
      return nil unless user_id

      user = User.find_by(id: user_id) || User.find_by(oauth_subject: user_id)
      return nil unless user

      # Return a hash with all identified_by attributes
      self.class.identifiers.each_with_object({}) do |identifier, hash|
        hash[identifier] = user if identifier == :user
        # Add support for other identifiers as needed
      end
    end

    def find_or_create_default_user
      # Only for development/testing with "none" authentication
      return nil unless Rails.env.development? || Rails.env.test?

      if defined?(User)
        User.find_or_create_by(email: "dev@localhost") do |user|
          user.name = "Development User" if user.respond_to?(:name=)
        end
      end
    end
  end
end

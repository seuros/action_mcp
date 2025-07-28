# frozen_string_literal: true

module ActionMCP
  # Base class for Gateway authentication identifiers.
  #
  # Gateway identifiers provide a clean interface for authentication by reading
  # from request.env keys set by upstream middleware (like Warden, Devise, or custom auth).
  #
  # @example Warden/Devise Integration
  #   class WardenIdentifier < ActionMCP::GatewayIdentifier
  #     identifier :user
  #     authenticates :warden
  #
  #     def resolve
  #       # Warden sets 'warden.user' in request.env after authentication
  #       user = user_from_middleware
  #       user || raise(Unauthorized, "No authenticated user found")
  #     end
  #   end
  #
  # @example API Key Authentication
  #   class ApiKeyIdentifier < ActionMCP::GatewayIdentifier
  #     identifier :user
  #     authenticates :api_key
  #
  #     def resolve
  #       # Check for API key in header or query param
  #       api_key = @request.env['HTTP_X_API_KEY'] ||
  #                 @request.params['api_key']
  #       return raise(Unauthorized, "Missing API key") unless api_key
  #
  #       user = User.find_by(api_key: api_key)
  #       user || raise(Unauthorized, "Invalid API key")
  #     end
  #   end
  #
  # @example Session-based Authentication
  #   class SessionIdentifier < ActionMCP::GatewayIdentifier
  #     identifier :user
  #     authenticates :session
  #
  #     def resolve
  #       user_id = session&.[]('user_id')
  #       return raise(Unauthorized, "No user session") unless user_id
  #
  #       user = User.find_by(id: user_id)
  #       user || raise(Unauthorized, "Invalid session")
  #     end
  #   end
  #
  # @example Multi-tenant with Organization
  #   class TenantIdentifier < ActionMCP::GatewayIdentifier
  #     identifier :user
  #     authenticates :tenant
  #
  #     def resolve
  #       # Get user from middleware
  #       user = user_from_middleware
  #       return raise(Unauthorized, "No user found") unless user
  #
  #       # Check tenant header
  #       tenant_id = @request.env['HTTP_X_TENANT_ID']
  #       return raise(Unauthorized, "Missing tenant") unless tenant_id
  #
  #       # Verify user has access to tenant
  #       unless user.tenants.exists?(id: tenant_id)
  #         raise Unauthorized, "Access denied for tenant"
  #       end
  #
  #       # Set current tenant for the request
  #       Current.tenant = Tenant.find(tenant_id)
  #       user
  #     end
  #   end
  #
  # @example Development/Testing Bypass
  #   class DevIdentifier < ActionMCP::GatewayIdentifier
  #     identifier :user
  #     authenticates :dev
  #
  #     def resolve
  #       return raise(Unauthorized, "Dev auth disabled in production") unless development_env?
  #
  #       # Create or find dev user
  #       User.find_or_create_by!(email: "dev@localhost") do |user|
  #         user.name = "Development User"
  #       end
  #     end
  #   end
  class GatewayIdentifier
    class Unauthorized < StandardError; end

    class << self
      # @return [Symbol] The name of the identity this identifier provides (e.g., :user, :admin)
      attr_reader :identifier_name

      # @return [String] The authentication method this identifier handles (e.g., "session", "api_key")
      attr_reader :auth_method

      # Declares what identity attribute this identifier provides.
      # This becomes the accessor name on the Gateway instance.
      #
      # @param name [Symbol, String] The identity name (e.g., :user, :admin)
      # @example
      #   identifier :user
      #   # Gateway instance will have gateway.user accessor
      def identifier(name)
        @identifier_name = name.to_sym
      end

      # Declares what authentication method this identifier handles.
      # This should match values in your authentication_methods configuration.
      #
      # @param method [Symbol, String] The auth method name (e.g., :session, :api_key)
      # @example
      #   authenticates :api_key
      #   # Matches authentication_methods: ["api_key"] in config
      def authenticates(method)
        @auth_method = method.to_s
      end
    end

    # @param request [ActionDispatch::Request] The request object containing env hash
    def initialize(request)
      @request = request
    end

    # Resolves the identity for this authentication method.
    # Must return a truthy identity object, or raise Unauthorized.
    #
    # Common request.env keys set by popular auth middleware:
    # - 'warden.user' - Warden (used by Devise)
    # - 'devise.user' - Devise direct
    # - 'rack.session' - Rack session hash
    # - 'HTTP_AUTHORIZATION' - Authorization header
    # - Custom keys set by your middleware
    #
    # @return [Object] The authenticated identity (User, Admin, etc.)
    # @raise [Unauthorized] When authentication fails
    # @abstract Subclasses must implement this method
    def resolve
      raise NotImplementedError, "#{self.class}#resolve must be implemented"
    end

    protected

    # Helper method to extract Bearer token from Authorization header
    # @return [String, nil] The token without "Bearer " prefix
    def extract_bearer_token
      header = @request.env["HTTP_AUTHORIZATION"] || ""
      header[/\ABearer (.+)\z/, 1]
    end

    # Helper method to extract Basic auth credentials from Authorization header
    # @return [Array<String>, nil] [username, password] or nil if not Basic auth
    def extract_basic_auth
      header = @request.env["HTTP_AUTHORIZATION"] || ""
      return nil unless header.start_with?("Basic ")

      encoded = header[6..-1] # Remove "Basic " prefix
      decoded = Base64.decode64(encoded)
      decoded.split(":", 2) # Split on first colon only
    rescue StandardError
      nil
    end

    # Helper method to get user from common middleware env keys
    # @return [Object, nil] User from Warden/Devise or nil
    def user_from_middleware
      @request.env["warden.user"] || @request.env["devise.user"]
    end

    # Helper method to get session hash
    # @return [Hash, nil] Rack session hash or nil
    def session
      @request.env["rack.session"]
    end

    # Helper method to read custom env key with optional fallbacks
    # @param keys [String, Array<String>] Primary key or array of keys to try
    # @return [Object, nil] Value from request.env or nil
    def env_value(*keys)
      keys.flatten.each do |key|
        value = @request.env[key]
        return value if value
      end
      nil
    end

    # Helper method to extract API key from various common locations
    # @param header_name [String] Custom header name (default: 'HTTP_X_API_KEY')
    # @param param_name [String] Query/form parameter name (default: 'api_key')
    # @return [String, nil] The API key or nil
    def extract_api_key(header_name: "HTTP_X_API_KEY", param_name: "api_key")
      # Try custom header first
      api_key = @request.env[header_name]
      return api_key if api_key

      # Try Authorization header with "Bearer" prefix
      bearer_token = extract_bearer_token
      return bearer_token if bearer_token

      # Try request parameters (query string or form data)
      @request.params[param_name] if @request.respond_to?(:params)
    end

    # Helper method to check if user is in a development environment
    # @return [Boolean] true if Rails.env.development?
    def development_env?
      Rails.env.development?
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  class UnauthorizedError < StandardError; end

  class Gateway
    # Whitelist of allowed identity attribute names to prevent method shadowing
    # and unauthorized attribute assignment. Extend this list if you use custom
    # identifier names in your GatewayIdentifier implementations.
    ALLOWED_IDENTITY_KEYS = %w[user api_key jwt bearer token account session].freeze

    class << self
      # pluck in one or many GatewayIdentifier classes
      def identified_by(*klasses)
        @identifier_classes = klasses.flatten
      end

      def identifier_classes
        @identifier_classes || []
      end
    end

    def initialize(request)
      @request = request
    end

    # called by your rack/websocket layer
    def call
      identities = authenticate!
      assign_identities(identities)
      self
    end

    protected

    def authenticate!
      active_identifiers = filter_active_identifiers

      raise ActionMCP::UnauthorizedError, "No authentication methods available" if active_identifiers.empty?

      # Try identifiers in order, use the first one that succeeds
      last_error = nil
      active_identifiers.each do |klass|
        result = klass.new(@request).resolve
        return { klass.identifier_name => result }
      rescue ActionMCP::GatewayIdentifier::Unauthorized => e
        last_error = e
        # Try next identifier
        next
      end

      # If we get here, all identifiers failed
      # Use the last specific error message if available, otherwise generic message
      error_message = last_error&.message || "Authentication failed"
      raise ActionMCP::UnauthorizedError, error_message
    end

    private

    def filter_active_identifiers
      configured_methods = ActionMCP.configuration.authentication_methods || []

      # If no authentication methods configured, use all identifiers
      return self.class.identifier_classes if configured_methods.empty?

      # Normalize configured methods to strings for consistent comparison
      normalized_methods = configured_methods.map(&:to_s)

      # Filter identifiers to only those matching configured authentication methods
      self.class.identifier_classes.select do |klass|
        normalized_methods.include?(klass.auth_method.to_s)
      end
    end

    def assign_identities(identities)
      identities.each do |name, value|
        name_str = name.to_s

        # Validate identity key against whitelist to prevent method shadowing
        unless ALLOWED_IDENTITY_KEYS.include?(name_str)
          raise ArgumentError, "Invalid identity key: '#{name_str}'. " \
                               "Allowed keys: #{ALLOWED_IDENTITY_KEYS.join(', ')}"
        end

        # define accessor on the fly
        self.class.attr_reader name unless respond_to?(name)
        instance_variable_set("@#{name_str}", value)

        # also set current context if you have one
        ActionMCP::Current.public_send("#{name_str}=", value) if
          ActionMCP::Current.respond_to?("#{name_str}=")
      end
      ActionMCP::Current.gateway = self if
        ActionMCP::Current.respond_to?(:gateway=)
    end
  end
end

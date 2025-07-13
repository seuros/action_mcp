# frozen_string_literal: true

module ActionMCP
  class GatewayIdentifier
    class Unauthorized < StandardError; end

    class << self
      # e.g. JwtIdentifier.identifier_name => :user
      attr_reader :identifier_name, :auth_method

      def identifier(name)
        @identifier_name = name.to_sym
      end

      def authenticates(method)
        @auth_method = method.to_s
      end
    end

    def initialize(request)
      @request = request
    end

    # must return a truthy identity object, or raise Unauthorized
    def resolve
      raise NotImplementedError, "#{self.class}#resolve must be implemented"
    end
  end
end

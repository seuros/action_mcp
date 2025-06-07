# frozen_string_literal: true

module ActionMCP
  module OAuth
    # Base OAuth error class
    class Error < StandardError
      attr_reader :oauth_error_code

      def initialize(message, oauth_error_code = "invalid_request")
        super(message)
        @oauth_error_code = oauth_error_code
      end
    end

    # OAuth 2.1 standard error types
    class InvalidRequestError < Error
      def initialize(message = "Invalid request")
        super(message, "invalid_request")
      end
    end

    class InvalidClientError < Error
      def initialize(message = "Invalid client")
        super(message, "invalid_client")
      end
    end

    class InvalidGrantError < Error
      def initialize(message = "Invalid grant")
        super(message, "invalid_grant")
      end
    end

    class UnauthorizedClientError < Error
      def initialize(message = "Unauthorized client")
        super(message, "unauthorized_client")
      end
    end

    class UnsupportedGrantTypeError < Error
      def initialize(message = "Unsupported grant type")
        super(message, "unsupported_grant_type")
      end
    end

    class InvalidScopeError < Error
      def initialize(message = "Invalid scope")
        super(message, "invalid_scope")
      end
    end

    class InvalidTokenError < Error
      def initialize(message = "Invalid token")
        super(message, "invalid_token")
      end
    end

    class InsufficientScopeError < Error
      attr_reader :required_scope

      def initialize(message = "Insufficient scope", required_scope = nil)
        super(message, "insufficient_scope")
        @required_scope = required_scope
      end
    end

    class ServerError < Error
      def initialize(message = "Server error")
        super(message, "server_error")
      end
    end

    class TemporarilyUnavailableError < Error
      def initialize(message = "Temporarily unavailable")
        super(message, "temporarily_unavailable")
      end
    end
  end
end

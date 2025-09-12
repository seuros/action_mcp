# frozen_string_literal: true

module ActionMCP
  module Logging
    # Null logger that performs no operations when logging is disabled
    # Provides the same interface as Logger but with zero overhead
    class NullLogger
      # Initialize a null logger (no-op)
      # @param args [Array] Any arguments (ignored)
      def initialize(*args, **kwargs)
        # Intentionally empty - no state needed
      end

      # Log methods - all no-ops that return nil immediately
      def debug(*args, **kwargs, &block)
        nil
      end

      def info(*args, **kwargs, &block)
        nil
      end

      def notice(*args, **kwargs, &block)
        nil
      end

      def warning(*args, **kwargs, &block)
        nil
      end
      alias_method :warn, :warning

      def error(*args, **kwargs, &block)
        nil
      end

      def critical(*args, **kwargs, &block)
        nil
      end

      def alert(*args, **kwargs, &block)
        nil
      end

      def emergency(*args, **kwargs, &block)
        nil
      end

      # Level check methods - all return false (nothing will be logged)
      def debug?
        false
      end

      def info?
        false
      end

      def notice?
        false
      end

      def warning?
        false
      end
      alias_method :warn?, :warning?

      def error?
        false
      end

      def critical?
        false
      end

      def alert?
        false
      end

      def emergency?
        false
      end

      # Implement any other methods that might be called to avoid NoMethodError
      def method_missing(method_name, *args, **kwargs, &block)
        # Return nil for any unknown method calls
        nil
      end

      def respond_to_missing?(method_name, include_private = false)
        # Pretend to respond to any method to avoid issues
        true
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  module Client
    # Base collection class for MCP client collections
    class Collection
      include RequestTimeouts

      attr_reader :client, :loaded

      def initialize(items, client, silence_sql: true)
        @collection_data = items || []
        @client = client
        @loaded = !@collection_data.empty?
        @silence_sql = silence_sql
      end

      def all
        silence_logs { load_items unless @loaded }
        @collection_data
      end

      def all!(timeout: DEFAULT_TIMEOUT)
        silence_logs { load_items(force: true, timeout: timeout) }
        @collection_data
      end

      # Filter items based on a given block
      #
      # @yield [item] Block that determines whether to include an item
      # @yieldparam item [Object] An item from the collection
      # @yieldreturn [Boolean] true to include the item, false to exclude it
      # @return [Array<Object>] Items that match the filter criteria
      def filter(&block)
        all.select(&block)
      end

      # Number of items in the collection
      #
      # @return [Integer] The number of items
      def size
        all.size
      end

      # Implements enumerable functionality
      include Enumerable

      def each(&block)
        all.each(&block)
      end

      alias loaded? loaded

      protected

      def load_items(force: false, timeout: DEFAULT_TIMEOUT)
        return if @loaded && !force

        # Make sure @load_method is defined in the subclass
        raise NotImplementedError, "Subclass must define @load_method" unless defined?(@load_method)

        # Use the RequestTimeouts module to handle the request
        load_with_timeout(@load_method, force: force, timeout: timeout)
      end

      private

      def silence_logs
        return yield unless @silence_sql

        original_log_level = Session.logger&.level
        begin
          # Temporarily increase log level to suppress SQL queries
          Session.logger.level = Logger::WARN if Session.logger
          yield
        ensure
          # Restore original log level
          Session.logger.level = original_log_level if Session.logger
        end
      end

      def log_error(message)
        # Safely handle logging - don't assume Rails.logger exists
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.error("[#{self.class.name}] #{message}")
        else
          # Fall back to puts if Rails.logger is not available
          puts "[ERROR] [#{self.class.name}] #{message}"
        end
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  module Client
    # Base collection class for MCP client collections
    class Collection
      include RequestTimeouts

      attr_reader :client, :loaded, :next_cursor, :total

      def initialize(items, client, silence_sql: true)
        @collection_data = items || []
        @client = client
        @loaded = !@collection_data.empty?
        @silence_sql = silence_sql
        @next_cursor = nil
        @total = items&.size || 0
      end

      def all(limit: nil)
        if limit
          # If a limit is provided, use pagination
          result = []
          each_page(limit: limit) { |page| result.concat(page) }
          result
        else
          # Otherwise, maintain the old behavior
          silence_logs { load_items unless @loaded }
          @collection_data
        end
      end

      def all!(timeout: DEFAULT_TIMEOUT)
        silence_logs { load_items(force: true, timeout: timeout) }
        @collection_data
      end

      # Fetch a single page of results
      #
      # @param cursor [String, nil] Optional cursor for pagination
      # @param limit [Integer, nil] Optional limit for page size
      # @return [Array<Object>] The page of items
      def page(cursor: nil, limit: nil)
        silence_logs { load_page(cursor: cursor, limit: limit) }
        @collection_data
      end

      # Check if there are more pages available
      #
      # @return [Boolean] true if there are more pages to fetch
      def has_more_pages?
        !@next_cursor.nil?
      end

      # Fetch the next page of results
      #
      # @param limit [Integer, nil] Optional limit for page size
      # @return [Array<Object>] The next page of items, or empty array if no more pages
      def next_page(limit: nil)
        return [] unless has_more_pages?

        page(cursor: @next_cursor, limit: limit)
      end

      # Iterate through all pages of results
      #
      # @param limit [Integer, nil] Optional limit for page size
      # @yield [page] Block to process each page
      # @yieldparam page [Array<Object>] A page of items
      def each_page(limit: nil)
        return unless block_given?

        current_page = page(limit: limit)
        yield current_page

        while has_more_pages?
          current_page = next_page(limit: limit)
          yield current_page unless current_page.empty?
        end
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

      def load_page(cursor: nil, limit: nil, timeout: DEFAULT_TIMEOUT)
        # Make sure @load_method is defined in the subclass
        raise NotImplementedError, "Subclass must define @load_method" unless defined?(@load_method)

        # Use the RequestTimeouts module to handle the request with pagination params
        params = {}
        params[:cursor] = cursor if cursor
        params[:limit] = limit if limit

        client.send(@load_method, params)

        start_time = Time.now
        sleep(0.1) while !@loaded && (Time.now - start_time) < timeout

        # Update @loaded status even if we timed out
        @loaded = true

        # Return the loaded data
        @collection_data
      end

      private

      def silence_logs
        return yield unless @silence_sql

        original_log_level = ActionMCP::Session.logger&.level
        begin
          # Temporarily increase log level to suppress SQL queries
          ActionMCP::Session.logger.level = Logger::WARN if ActionMCP::Session.logger
          yield
        ensure
          # Restore original log level
          ActionMCP::Session.logger.level = original_log_level if ActionMCP::Session.logger && original_log_level
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

module ActionMCP
  module Transport
    class TransportBase
      attr_reader :logger

      def initialize(logger: Logger.new(STDOUT))
        @logger = logger
        @on_message = nil
        @on_error = nil
      end

      def on_message(&block)
        @on_message = block
      end

      def on_error(&block)
        @on_error = block
      end

      protected

      def handle_raw_message(raw)
        @logger.debug("[#{self.class.name.split('::').last}] <-- #{raw}")
        msg_hash = MultiJson.load(raw)
        response = Message::Response.new(msg_hash)
        @on_message&.call(response)
      rescue StandardError => e
        @logger.error("JSON parse error: #{e} (raw: #{raw})")
        @on_error&.call(e) if @on_error
      end

      def log_debug(message)
        @logger.debug("[#{log_prefix}] #{message}")
      end

      def log_info(message)
        @logger.info("[#{log_prefix}] #{message}")
      end

      def log_error(message)
        @logger.error("[#{log_prefix}] #{message}")
      end

      private

      def log_prefix
        self.class.name.split("::").last
      end
    end
  end
end

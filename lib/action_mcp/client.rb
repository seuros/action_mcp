# frozen_string_literal: true

module ActionMCP
  class Client
    attr_reader :transport
    delegate :logger, :ready?, to: :transport
    def initialize(endpoint:, logger: Logger.new(STDOUT))
      if endpoint =~ /\Ahttps?:\/\//
        @transport = Transport::SSE.new(endpoint, logger: logger)
      else
        @transport = Transport::Stdio.new(endpoint, logger: logger)
      end

      # Set up message handling
      @transport.on_message { |msg| handle_message(msg) }
      @transport.on_error { |err| handle_error(err) }
    end

    def connect
      @transport.start
    end

    def send_request(payload)
      json = MultiJson.dump(payload)
      @transport.send_message(json)
    end

    def disconnect
      @transport.stop
    end
  end
end

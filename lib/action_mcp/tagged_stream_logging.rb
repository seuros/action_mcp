# frozen_string_literal: true

module ActionMCP
  module TaggedStreamLogging
    # ────────────  ANSI COLOURS  ────────────
    CLR        = "\e[0m"
    BLUE_TX    = "\e[34m"  # outgoing JSON‑RPC (TX)
    GREEN_RX   = "\e[32m"  # incoming JSON‑RPC (RX)
    YELLOW_ERR = "\e[33m"  # decode / validation warnings
    RED_FATAL  = "\e[31m"  # unexpected exceptions

    # ———  Outbound: any frame we ‘write’ to the wire  ———
    def write_message(data)
      pretty = json_normalise(data)
      log_frame("TX", :debug, BLUE_TX, pretty)
      super
    rescue StandardError => e
      log_frame("TX", :error, RED_FATAL, e.message)
      raise
    end

    # ———  Inbound: every raw line handed to the JSON‑RPC handler  ———
    def read(line)
      pretty = json_normalise(line)
      log_frame("RX", :debug, GREEN_RX, pretty)
      super
    rescue MultiJSON::ParseError => e
      log_frame("RX", :warn, YELLOW_ERR, "Bad JSON → #{e.message}")
      raise
    rescue StandardError => e
      log_frame("RX", :error, RED_FATAL, e.message)
      raise
    end

    private

    def log_frame(direction, level, color, text)
      log_with_tags("MCP", direction) { ActionMCP.logger.public_send(level, "#{color}#{text}#{CLR}") }
    end

    # Helper method to handle tagged logging across different logger types
    def log_with_tags(*tags, &block)
      if ActionMCP.logger.respond_to?(:tagged)
        ActionMCP.logger.tagged(*tags, &block)
      else
        # For loggers that don't support tagging (like BroadcastLogger),
        # prepend tags to the message
        original_formatter = ActionMCP.logger.formatter
        tag_string = "[#{tags.join('] [')}] "
        ActionMCP.logger.formatter = proc do |severity, datetime, progname, msg|
          formatted_msg = original_formatter ? original_formatter.call(severity, datetime, progname, msg) : msg
          "#{tag_string}#{formatted_msg}"
        end
        begin
          yield
        ensure
          ActionMCP.logger.formatter = original_formatter if original_formatter
        end
      end
    end

    # Accepts String, Hash, or any #to_json‑able object.
    def json_normalise(obj)
      str = obj.is_a?(String) ? obj.strip : MultiJSON.generate(obj)
      str.empty? ? "<empty frame>" : str
    end
  end
end

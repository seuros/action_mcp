# frozen_string_literal: true

# frozen_string_literal: true

# lib/action_mcp/tagged_io_logging.rb

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
      ActionMCP.logger.tagged("MCP", "TX") { ActionMCP.logger.debug("#{BLUE_TX}#{pretty}#{CLR}") }
      super
    rescue StandardError => e
      ActionMCP.logger.tagged("MCP", "TX") { ActionMCP.logger.error("#{RED_FATAL}#{e.message}#{CLR}") }
      raise
    end

    # ———  Inbound: every raw line handed to the JSON‑RPC handler  ———
    def read(line)
      pretty = json_normalise(line)
      ActionMCP.logger.tagged("MCP", "RX") { ActionMCP.logger.debug("#{GREEN_RX}#{pretty}#{CLR}") }
      super
    rescue MultiJson::ParseError => e
      ActionMCP.logger.tagged("MCP", "RX") { ActionMCP.logger.warn("#{YELLOW_ERR}Bad JSON → #{e.message}#{CLR}") }
      raise
    rescue StandardError => e
      ActionMCP.logger.tagged("MCP", "RX") { ActionMCP.logger.error("#{RED_FATAL}#{e.message}#{CLR}") }
      raise
    end

    private

    # Accepts String, Hash, or any #to_json‑able object.
    def json_normalise(obj)
      str = obj.is_a?(String) ? obj.strip : MultiJson.dump(obj)
      str.empty? ? "<empty frame>" : str
    end
  end
end

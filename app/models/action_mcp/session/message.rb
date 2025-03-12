module ActionMCP
  class Session::Message < ApplicationRecord
    belongs_to :session,
               class_name: "ActionMCP::Session",
               inverse_of: :messages,
               counter_cache: true

    delegate :adapter,
             :role,
             :session_key,
             to: :session

    # Virtual attribute for data
    attr_reader :data

    after_create_commit :broadcast_message, if: :outgoing_message?

    # @param payload [String, Hash]
    def data=(payload)
      @data = payload

      # Store original version and attempt to determine type
      if payload.is_a?(String)
        self.message_text = payload

        begin
          parsed_json = MultiJson.load(payload)
          self.message_json = parsed_json
          process_json_content(parsed_json)
        rescue MultiJson::ParseError
          # Not valid JSON, just store as text
          self.message_type = "text"
        end
      else
        # Handle Hash or other JSON-serializable input
        self.message_json = payload
        self.message_text = MultiJson.dump(payload)
        process_json_content(payload)
      end
    end

    def data
      message_json.presence || message_text
    end

    # Helper method to check if message is a particular type
    def request?
      message_type == "request"
    end

    def notification?
      message_type == "notification"
    end

    def response?
      message_type == "response"
    end

    private

    def outgoing_message?
      direction != role
    end

    def broadcast_message
      adapter.broadcast(session_key, data.to_json)
    end

    def process_json_content(content)
      # Determine message type based on JSON-RPC spec
      if content.is_a?(Hash) && content["jsonrpc"] == "2.0"
        if content.key?("id") && content.key?("method")
          self.message_type = "request"
          self.jsonrpc_id = content["id"]
        elsif content.key?("method") && !content.key?("id")
          self.message_type = "notification"
        elsif content.key?("id") && content.key?("result")
          self.message_type = "response"
          self.jsonrpc_id = content["id"]
        elsif content.key?("id") && content.key?("error")
          self.message_type = "error"
          self.jsonrpc_id = content["id"]
        else
          self.message_type = "invalid_jsonrpc"
        end
      else
        self.message_type = "non_jsonrpc_json"
      end
    end
  end
end

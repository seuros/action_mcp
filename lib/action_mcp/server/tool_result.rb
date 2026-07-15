# frozen_string_literal: true

module ActionMCP
  module Server
    module ToolResult
      module_function

      def normalize(response)
        payload = response.to_h
        code = payload[:code] || payload["code"]
        return response unless response.error? && code == -32_602

        execution_error(
          payload[:message] || payload["message"],
          data: payload[:data] || payload["data"]
        )
      end

      def execution_error(message, data: nil)
        details = data.is_a?(Array) ? data.join(", ") : nil
        text = [ message, details ].compact_blank.join(": ")

        ToolResponse.new.tap { |response| response.report_tool_error(text) }
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  module Transport
    module Roots
      def send_roots_list(id)
        send_jsonrpc_response(id, result: { roots: [] })
      end
    end
  end
end

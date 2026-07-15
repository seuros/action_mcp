# frozen_string_literal: true

module ActionMCP
  module Server
    module Roots
      def send_roots_list(id = SecureRandom.uuid_v7)
        roots = session.client_capabilities&.then { |capabilities| capabilities["roots"] || capabilities[:roots] }
        raise UnsupportedRootsError, "Client does not support roots" unless roots.is_a?(Hash)

        send_jsonrpc_request("roots/list", id: id)
      end

      def refresh_roots_list
        roots = session.client_capabilities&.then { |capabilities| capabilities["roots"] || capabilities[:roots] }
        return unless roots.is_a?(Hash)

        list_changed = roots["listChanged"] || roots[:listChanged]
        send_roots_list if list_changed == true
      end
    end

    class UnsupportedRootsError < StandardError; end
  end
end

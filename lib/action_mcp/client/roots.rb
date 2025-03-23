# frozen_string_literal: true

module ActionMCP
  module Client
    module Roots
      # Notify the server that the roots list has changed
      def roots_list_changed_notification
        send_jsonrpc_notification("notifications/roots/list_changed")
        true
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  # Module for handling JSON-RPC communication.
  module JsonRpc
    extend ActiveSupport::Autoload

    autoload :JsonRpcError
    autoload :Notification
    autoload :Request
    autoload :Response
  end
end

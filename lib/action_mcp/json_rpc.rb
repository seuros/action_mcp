# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    extend ActiveSupport::Autoload

    autoload :Base
    autoload :JsonRpcError
    autoload :Notification
    autoload :Request
    autoload :Response
  end
end

module ActionMCP
  module Transport
    extend ActiveSupport::Autoload

    autoload :Capabilities
    autoload :Resources
    autoload :Tools
    autoload :Prompts
    autoload :Messaging

    autoload :TransportBase
    autoload :SSEServer
    autoload :Stdio
    autoload :SSE
  end
end


# TODO: move all server related code here before version 1.0.0
module ActionMCP
  # Module for server-related functionality.
  module Server
    module_function def server
      @server ||= ActionCable::Server::Base.new
    end
  end
end

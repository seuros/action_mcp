# frozen_string_literal: true

module ActionMCP
  VERSION = "0.2.0"

  class << self
    # Returns the currently loaded version of Active MCP as a +Gem::Version+.
    #
    # @return [Gem::Version] the currently loaded version of Active MCP
    def gem_version
      Gem::Version.new VERSION
    end

    alias version gem_version
  end
end

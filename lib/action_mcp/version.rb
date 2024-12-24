# frozen_string_literal: true

require_relative "gem_version"

module ActionMCP
  VERSION = "0.1.0"
  # Returns the currently loaded version of Active MCP as a +Gem::Version+.
  def self.version
    gem_version
  end
end

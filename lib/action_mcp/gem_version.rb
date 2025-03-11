module ActionMCP
  # Returns the currently loaded version of Active MCP as a +Gem::Version+.
  #
  # @return [Gem::Version] the currently loaded version of Active MCP
  def self.gem_version
    Gem::Version.new VERSION
  end
end

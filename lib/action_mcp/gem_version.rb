module ActionMCP
  # Returns the currently loaded version of Active MCP as a +Gem::Version+.
  def self.gem_version
    Gem::Version.new VERSION
  end
end

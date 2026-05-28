# frozen_string_literal: true

require_relative "gem_version"
module ActionMCP
  VERSION = "0.110.2"

  class << self
    alias version gem_version
  end
end

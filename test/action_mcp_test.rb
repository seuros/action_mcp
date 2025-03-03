
# frozen_string_literal: true

require "test_helper"

class ActionMCPTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert ActionMCP::VERSION
    assert_instance_of Gem::Version, ActionMCP.gem_version
  end

  test "truth" do
    assert true
  end
end

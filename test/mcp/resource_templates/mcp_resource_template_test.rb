# frozen_string_literal: true

require "test_helper"
class MCPResourceTemplateTest < ActiveSupport::TestCase
  test "should be abstract" do
    assert ApplicationMCPResTemplate.abstract?
  end
end

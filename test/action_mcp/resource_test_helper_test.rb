# frozen_string_literal: true

require "test_helper"
require "action_mcp/test_helper"

class ResourceTestHelperTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "assert_mcp_resource_template_findable finds registered template" do
    assert_mcp_resource_template_findable("products")
  end

  test "assert_mcp_resource_template_findable fails for unknown template" do
    assert_raises(Minitest::Assertion) do
      assert_mcp_resource_template_findable("nonexistent")
    end
  end

  test "resolve_mcp_resource resolves a valid URI" do
    resp = resolve_mcp_resource("ecommerce://products/1")

    assert resp.success?
    assert_not_empty resp.contents
    content = resp.contents.first
    assert_equal "application/json", content.mime_type
  end

  test "resolve_mcp_resource fails for unknown URI scheme" do
    assert_raises(Minitest::Assertion) do
      resolve_mcp_resource("unknown://something/1")
    end
  end

  test "resolve_mcp_resource_with_error returns error for not found resource" do
    resp = resolve_mcp_resource_with_error("ecommerce://products/0")

    assert resp.is_error
  end
end

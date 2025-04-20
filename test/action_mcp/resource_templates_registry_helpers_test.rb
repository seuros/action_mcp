# frozen_string_literal: true

require "test_helper"

class RtrHelpersTest < ActiveSupport::TestCase
  # Local dummy template so we don't touch the global registry
  class PathTemplate < ActionMCP::ResourceTemplate
    uri_template "alpha://foo/{bar}/baz"
    description  "dummy"
  end

  def setup
    @template = PathTemplate
  end

  test "uri_matches_template? false when schema differs" do
    refute ActionMCP::ResourceTemplatesRegistry
      .uri_matches_template?("beta://foo/123/baz", @template)
  end

  test "uri_matches_template? false on segment‑count mismatch" do
    refute ActionMCP::ResourceTemplatesRegistry
      .uri_matches_template?("alpha://foo/123", @template)
  end

  test "extract_parameters returns {} when not matching" do
    params = ActionMCP::ResourceTemplatesRegistry
             .extract_parameters("alpha://foo/123", @template)
    assert_empty params
  end

  test "extract_parameters populates params when matching" do
    params = ActionMCP::ResourceTemplatesRegistry
             .extract_parameters("alpha://foo/99/baz", @template)
    assert_equal({ bar: "99" }, params)
  end
end

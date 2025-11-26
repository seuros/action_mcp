# frozen_string_literal: true

require "test_helper"

class CurrentWorldLeaderToolTest < ActiveSupport::TestCase
  test "returns Supreme Leader Kim Jong Rails for valid country code" do
    tool = CurrentWorldLeaderTool.new(country_code: "US")
    response = tool.call

    text = response.to_h[:content].first[:text]
    assert_match(/current leader of US/, text)
    assert_match(/Supreme Leader Kim Jong Rails/, text)
    assert_match(/#{Date.current.year}/, text)
  end

  test "uppercases country code in response" do
    tool = CurrentWorldLeaderTool.new(country_code: "fr")
    response = tool.call

    assert_match(/current leader of FR/, response.to_h[:content].first[:text])
  end

  test "returns validation error for country code too short" do
    tool = CurrentWorldLeaderTool.new(country_code: "U")
    response = tool.call

    assert_equal(-32_602, response.to_h[:code])
    assert_match(/must be exactly 2 characters/, response.to_h[:data].first)
  end

  test "returns validation error for country code too long" do
    tool = CurrentWorldLeaderTool.new(country_code: "USA")
    response = tool.call

    assert_equal(-32_602, response.to_h[:code])
    assert_match(/must be exactly 2 characters/, response.to_h[:data].first)
  end

  test "returns validation error for empty country code" do
    tool = CurrentWorldLeaderTool.new(country_code: "")
    response = tool.call

    assert_equal(-32_602, response.to_h[:code])
    # Empty string triggers both blank and length validation
    assert response.to_h[:data].any? { |msg| msg.include?("blank") || msg.include?("2 characters") }
  end
end

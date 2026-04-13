# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class UrlElicitationRequestTest < ActiveSupport::TestCase
      test "valid with https url" do
        request = UrlElicitationRequest.new(
          message: "Please authenticate",
          url: "https://example.com/auth"
        )

        assert request.valid?
      end

      test "valid with http url" do
        request = UrlElicitationRequest.new(
          message: "Dev auth",
          url: "http://localhost:3000/auth"
        )

        assert request.valid?
      end

      test "auto-generates elicitation_id when not provided" do
        request = UrlElicitationRequest.new(
          message: "Auth",
          url: "https://example.com/auth"
        )

        assert_not_nil request.elicitation_id
        assert request.elicitation_id.present?
      end

      test "preserves provided elicitation_id" do
        request = UrlElicitationRequest.new(
          message: "Auth",
          url: "https://example.com/auth",
          elicitation_id: "custom-id-123"
        )

        assert_equal "custom-id-123", request.elicitation_id
      end

      test "to_params builds correct wire format" do
        request = UrlElicitationRequest.new(
          message: "Auth needed",
          url: "https://example.com/oauth",
          elicitation_id: "e-1"
        )

        params = request.to_params
        assert_equal "url", params[:mode]
        assert_equal "Auth needed", params[:message]
        assert_equal "https://example.com/oauth", params[:url]
        assert_equal "e-1", params[:elicitationId]
        assert_nil params[:_meta]
      end

      test "to_params includes _meta when present" do
        request = UrlElicitationRequest.new(
          message: "Auth",
          url: "https://example.com/auth",
          _meta: { taskId: "task-1" }
        )

        assert_includes request.to_params, :_meta
      end

      test "invalid without message" do
        request = UrlElicitationRequest.new(url: "https://example.com/auth")

        assert_not request.valid?
        assert_includes request.errors[:message], "can't be blank"
      end

      test "invalid without url" do
        request = UrlElicitationRequest.new(message: "test", url: "")

        assert_not request.valid?
        assert_includes request.errors[:url], "can't be blank"
      end

      test "invalid with ftp url" do
        request = UrlElicitationRequest.new(
          message: "test",
          url: "ftp://example.com/file"
        )

        assert_not request.valid?
        assert request.errors[:url].any? { |e| e.include?("HTTP") }
      end

      test "invalid with malformed url" do
        request = UrlElicitationRequest.new(
          message: "test",
          url: "not a url at all %%"
        )

        assert_not request.valid?
        assert request.errors[:url].any?
      end

      test "invalid with javascript url" do
        request = UrlElicitationRequest.new(
          message: "test",
          url: "javascript:alert(1)"
        )

        assert_not request.valid?
      end

      test "invalid with hostless http url" do
        request = UrlElicitationRequest.new(
          message: "test",
          url: "http://"
        )

        assert_not request.valid?
        assert request.errors[:url].any? { |e| e.include?("host") }
      end

      test "invalid with scheme-only https url" do
        request = UrlElicitationRequest.new(
          message: "test",
          url: "https://"
        )

        assert_not request.valid?
      end

      test "assert_valid! raises ArgumentError on invalid" do
        request = UrlElicitationRequest.new(message: "test", url: "ftp://bad.com")

        error = assert_raises(ArgumentError) { request.assert_valid! }
        assert_match(/HTTP/, error.message)
      end

      test "assert_valid! does not raise on valid" do
        request = UrlElicitationRequest.new(
          message: "Auth",
          url: "https://example.com/auth"
        )

        assert_nothing_raised { request.assert_valid! }
      end
    end
  end
end

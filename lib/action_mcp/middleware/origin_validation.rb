# frozen_string_literal: true

require "uri"

module ActionMCP
  module Middleware
    # Rack middleware that validates the Origin header on MCP requests to
    # prevent DNS rebinding attacks per the MCP Streamable HTTP security
    # section. Non-browser clients (Claude Desktop, curl) never send Origin
    # and are always allowed. Present Origins must match the explicitly trusted
    # hosts in `ActionMCP.configuration.allowed_origins`.
    #
    # Runs as middleware — same layer as `ActionDispatch::HostAuthorization` —
    # so invalid requests are rejected before they reach routing.
    class OriginValidation
      INVALID_REQUEST_CODE = -32_600

      # @param app [#call]
      # @param paths [Array<String, Regexp, Proc>, nil] paths to guard.
      #   Nil or empty means every request is guarded.
      def initialize(app, paths = nil)
        @app = app
        @paths = Array(paths)
      end

      def call(env)
        return @app.call(env) unless guard_path?(env["PATH_INFO"])

        request = ActionDispatch::Request.new(env)
        origin = request.origin
        return @app.call(env) if origin.nil?
        return @app.call(env) if origin_allowed?(origin, request)

        forbidden_response
      end

      private

      def guard_path?(path)
        return true if @paths.empty?

        @paths.any? do |matcher|
          case matcher
          when String then path == matcher
          when Regexp then matcher.match?(path)
          when Proc   then matcher.call(path)
          else             false
          end
        end
      end

      def origin_allowed?(origin, _request)
        return false if origin == "null"

        uri = URI.parse(origin)
        return false unless %w[http https].include?(uri.scheme)
        return false if uri.host.nil? || uri.host.empty? || uri.userinfo || uri.query || uri.fragment
        return false unless uri.path.empty?

        origin_host = strip_brackets(uri.host)
        allowed = Array(ActionMCP.configuration.allowed_origins)
        allowed.any? { |pattern| match?(pattern, origin_host) }
      rescue URI::InvalidURIError
        false
      end

      def match?(pattern, host)
        case pattern
        when Regexp then pattern.match?(host)
        when String then host.casecmp?(strip_brackets(pattern))
        else             false
        end
      end

      def strip_brackets(host)
        host.to_s.delete_prefix("[").delete_suffix("]")
      end

      def forbidden_response
        body = {
          jsonrpc: "2.0",
          id: nil,
          error: { code: INVALID_REQUEST_CODE, message: "Forbidden: invalid Origin header" }
        }.to_json

        [ 403, { "Content-Type" => "application/json" }, [ body ] ]
      end
    end
  end
end

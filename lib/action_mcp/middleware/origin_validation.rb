# frozen_string_literal: true

require "uri"

module ActionMCP
  module Middleware
    # Rack middleware that validates the Origin header on MCP requests to
    # prevent DNS rebinding attacks per the MCP Streamable HTTP security
    # section. Non-browser clients (Claude Desktop, curl) never send Origin
    # and are always allowed. Present Origins must match either
    # `ActionMCP.configuration.allowed_origins` or the server's own host.
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

        origin = env["HTTP_ORIGIN"]
        return @app.call(env) if origin.nil? || origin.empty?
        return @app.call(env) if origin_allowed?(origin, env)

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

      def origin_allowed?(origin, env)
        return false if origin == "null"

        uri = URI.parse(origin)
        return false if uri.host.nil? || uri.host.empty?

        origin_host = strip_brackets(uri.host)
        allowed = ActionMCP.configuration.allowed_origins

        if allowed && !allowed.empty?
          allowed.any? { |pattern| match?(pattern, origin_host) }
        else
          origin_host.casecmp?(strip_brackets(server_host(env)))
        end
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

      def server_host(env)
        host = env["HTTP_HOST"] || env["SERVER_NAME"] || ""
        # Strip port. IPv6 literals are bracketed ("[::1]:3000"); non-bracketed
        # hosts use the first colon ("localhost:3000").
        if host.start_with?("[")
          closing = host.index("]")
          closing ? host[0..closing] : host
        else
          host.split(":", 2).first.to_s
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

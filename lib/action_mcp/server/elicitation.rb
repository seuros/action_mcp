# frozen_string_literal: true

require_relative "elicitation_request"
require_relative "url_elicitation_request"

module ActionMCP
  module Server
    # Handles elicitation requests from the server to the client.
    #
    # Two modes per MCP 2025-11-25:
    #   - Form mode: structured data collection with JSON Schema validation
    #   - URL mode: out-of-band interaction via external URL (sensitive data, OAuth flows)
    module Elicitation
      URL_ELICITATION_REQUIRED_CODE = -32_042

      # Send a form mode elicitation request to the client.
      # @param message [String] Human-readable message explaining why input is needed
      # @param requested_schema [Hash] JSON Schema for the expected response (primitive types only)
      # @param _meta [Hash] Optional metadata (e.g. related task)
      def send_elicitation_create(message:, requested_schema:, _meta: {})
        require_client_elicitation_support!(:form)

        request = ElicitationRequest.new(
          message: message,
          requested_schema: requested_schema,
          _meta: _meta
        )
        request.assert_valid!

        send_jsonrpc_request("elicitation/create", params: request.to_params)
      end

      # Send a URL mode elicitation request to the client.
      # Used for sensitive data collection (API keys, OAuth, payments) that must not
      # pass through the MCP client.
      # @param message [String] Human-readable message explaining why navigation is needed
      # @param url [String] The URL the user should navigate to
      # @param elicitation_id [String] Unique identifier for this elicitation
      # @param _meta [Hash] Optional metadata (e.g. related task)
      def send_elicitation_create_url(message:, url:, elicitation_id: nil, _meta: {})
        require_client_elicitation_support!(:url)

        request = UrlElicitationRequest.new(
          message: message,
          url: url,
          elicitation_id: elicitation_id,
          _meta: _meta
        )
        request.assert_valid!

        send_jsonrpc_request("elicitation/create", params: request.to_params)
      end

      # Send a completion notification for a URL mode elicitation.
      # Informs the client that the out-of-band interaction has completed.
      # @param elicitation_id [String] The elicitation ID from the original request
      def send_elicitation_complete_notification(elicitation_id)
        require_client_elicitation_support!(:url)
        send_jsonrpc_notification(
          "notifications/elicitation/complete",
          { elicitationId: elicitation_id }
        )
      end

      # Build a URLElicitationRequiredError response (-32042).
      # Used when a request cannot proceed until an elicitation is completed.
      # @param request_id [String, Integer] The JSON-RPC request ID to respond to
      # @param message [String] Human-readable error message
      # @param elicitations [Array<Hash>] Required URL mode elicitations
      def send_url_elicitation_required_error(request_id, message:, elicitations:)
        require_client_elicitation_support!(:url)

        elicitations.each do |e|
          raise ArgumentError, "Each elicitation must have mode: 'url'" unless e[:mode] == "url"
          raise ArgumentError, "Each elicitation must have an elicitationId" unless e[:elicitationId].present?

          UrlElicitationRequest.new(
            message: e[:message],
            url: e[:url],
            elicitation_id: e[:elicitationId]
          ).assert_valid!
        end

        error = {
          code: URL_ELICITATION_REQUIRED_CODE,
          message: message,
          data: { elicitations: elicitations }
        }

        send_jsonrpc_response(request_id, error: error)
      end

      private

      # Check that the client declared support for the given elicitation mode.
      # Elicitation is a client capability — servers MUST NOT send modes the client didn't declare.
      def require_client_elicitation_support!(mode)
        client_caps = session.client_capabilities || {}
        elicitation_caps = client_caps["elicitation"] || client_caps[:elicitation]

        raise UnsupportedElicitationError, "Client does not support elicitation" unless elicitation_caps.is_a?(Hash)

        if mode == :form
          # Empty hash or explicit form: {} both mean form support (backward compat with 2025-06-18)
          # But if client only declared url: {} without form, reject
          form_cap = elicitation_caps["form"] || elicitation_caps[:form]
          unless elicitation_caps.empty? || form_cap
            raise UnsupportedElicitationError, "Client does not support form mode elicitation"
          end
          return
        end

        # URL mode requires protocol version 2025-11-25+
        unless session.protocol_version == "2025-11-25"
          raise UnsupportedElicitationError, "URL mode elicitation requires protocol version 2025-11-25"
        end

        # Client must explicitly declare url mode support (empty hash = form-only for 2025-06-18 clients)
        url_cap = elicitation_caps["url"] || elicitation_caps[:url]
        raise UnsupportedElicitationError, "Client does not support URL mode elicitation" unless url_cap
      end
    end

    class UnsupportedElicitationError < StandardError; end
  end
end

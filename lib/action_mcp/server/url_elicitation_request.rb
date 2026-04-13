# frozen_string_literal: true

require "uri"

module ActionMCP
  module Server
    # Value object for URL-mode elicitation requests.
    # Used for sensitive data collection (API keys, OAuth, payments)
    # that must not pass through the MCP client.
    class UrlElicitationRequest
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :message, :string
      attribute :url, :string
      attribute :elicitation_id, :string
      attribute :_meta # Hash, optional

      validates :message, presence: true
      validates :url, presence: true
      validate :url_must_be_valid_http, if: -> { url.present? }

      def initialize(attributes = {})
        super
        self.elicitation_id = SecureRandom.uuid_v7 if elicitation_id.blank?
      end

      # @return [Hash] JSON-RPC params for elicitation/create
      def to_params
        params = {
          mode: "url",
          message: message,
          url: url,
          elicitationId: elicitation_id
        }
        params[:_meta] = _meta if _meta.present?
        params
      end

      # Validates and raises ArgumentError on failure (preserving public API).
      # Named assert_valid! to avoid shadowing ActiveModel#validate!
      def assert_valid!
        return if valid?

        raise ArgumentError, errors.full_messages.join(", ")
      end

      private

      def url_must_be_valid_http
        parsed = URI.parse(url)
        unless parsed.is_a?(URI::HTTP) && parsed.host.present?
          errors.add(:url, "must be an HTTP or HTTPS URL with a host")
        end
      rescue URI::InvalidURIError
        errors.add(:url, "is not a valid URI")
      end
    end
  end
end

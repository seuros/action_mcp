# frozen_string_literal: true

module ActionMCP
  # Runs a block inside the Rails reloader in development so edited components
  # are picked up, carrying ActionMCP::Current across the reloader boundary.
  module DevReloader
    CARRIED_CURRENT_ATTRIBUTES = %i[user gateway session_data].freeze

    def self.wrap
      return yield unless Rails.env.development? && Rails.application&.reloader

      carried = CARRIED_CURRENT_ATTRIBUTES.index_with { |attribute| ActionMCP::Current.public_send(attribute) }
      Rails.application.reloader.wrap do
        carried.each { |attribute, value| ActionMCP::Current.public_send(:"#{attribute}=", value) }
        yield
      end
    end
  end
end

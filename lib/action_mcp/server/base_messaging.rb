# frozen_string_literal: true

module ActionMCP
  module Server
    # Base messaging functionality
    module BaseMessaging
      private

      def write_message(data)
        session.write(data)
      end
    end
  end
end

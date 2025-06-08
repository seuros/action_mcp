# frozen_string_literal: true

module ActionMCP
  module Client
    class OauthClientProvider
      # Simple in-memory storage for development
      # In production, use persistent storage
      class MemoryStorage
        def initialize
          @data = {}
        end

        def save_tokens(tokens)
          @data[:tokens] = tokens
        end

        def load_tokens
          @data[:tokens]
        end

        def clear_tokens
          @data.delete(:tokens)
        end

        def save_code_verifier(verifier)
          @data[:code_verifier] = verifier
        end

        def load_code_verifier
          @data[:code_verifier]
        end

        def clear_code_verifier
          @data.delete(:code_verifier)
        end

        def save_client_information(info)
          @data[:client_information] = info
        end

        def load_client_information
          @data[:client_information]
        end
      end
    end
  end
end

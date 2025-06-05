# frozen_string_literal: true

module ActionMCP
  class UnauthorizedError < StandardError; end

  class Gateway
    class << self
      def identified_by(*attrs)
        @identifiers ||= []
        @identifiers.concat(attrs.map(&:to_sym)).uniq!
        attr_accessor(*attrs)
      end

      def identifiers
        @identifiers ||= []
      end
    end

    identified_by :user

    attr_reader :request

    def call(request)
      @request = request
      connect
      self
    end

    def connect
      identities = authenticate!
      reject_unauthorized_connection unless identities.is_a?(Hash)

      # Assign all identities (e.g., :user, :account)
      self.class.identifiers.each do |id|
        value = identities[id]
        reject_unauthorized_connection unless value

        public_send("#{id}=", value)

        # Set to ActionMCP::Current
        ActionMCP::Current.public_send("#{id}=", value)
      end

      # Also set the gateway instance itself
      ActionMCP::Current.gateway = self
    end


    protected

    def authenticate!
      token = extract_bearer_token
      raise UnauthorizedError, "Missing token" unless token

      payload = ActionMCP::JwtDecoder.decode(token)
      resolve_user(payload)
    rescue ActionMCP::JwtDecoder::DecodeError => e
      raise UnauthorizedError, e.message
    end

    def extract_bearer_token
      header = request.headers["Authorization"] || request.headers["authorization"]
      return nil unless header&.start_with?("Bearer ")
      header.split(" ", 2).last
    end

    def resolve_user(payload)
      return nil unless payload.is_a?(Hash)
      user_id = payload["user_id"] || payload["sub"]
      return nil unless user_id
      user = User.find_by(id: user_id)
      return nil unless user

      # Return a hash with all identified_by attributes
      self.class.identifiers.each_with_object({}) do |identifier, hash|
        hash[identifier] = user if identifier == :user
        # Add support for other identifiers as needed
      end
    end

    def reject_unauthorized_connection
      raise UnauthorizedError, "Unauthorized"
    end
  end
end

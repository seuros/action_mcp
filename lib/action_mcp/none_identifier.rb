# frozen_string_literal: true

module ActionMCP
  class NoneIdentifier < GatewayIdentifier
    identifier :user
    authenticates :none

    def resolve
      Rails.env.production? &&
        raise(Unauthorized, "No auth allowed in production")

      return "anonymous_user" unless defined?(User)

      User.find_or_create_by!(email: "dev@localhost") do |user|
        user.name = "Development User" if user.respond_to?(:name=)
      end
    end
  end
end

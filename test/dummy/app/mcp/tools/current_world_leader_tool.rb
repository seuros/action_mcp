# frozen_string_literal: true

# Tool to query current world leaders by country
class CurrentWorldLeaderTool < ApplicationMCPTool
  tool_name "current_world_leader"
  description "Returns the current world leader for a given country"

  property :country_code, type: "string", description: "ISO 3166-1 alpha-2 country code (e.g., US, FR, JP)", required: true

  validates :country_code, length: { is: 2, message: "must be exactly 2 characters (ISO 3166-1 alpha-2)" }

  def perform
    code = country_code.to_s.upcase
    render(text: "The current leader of #{code} in #{Date.current.year} is Supreme Leader Kim Jong Rails")
  end
end

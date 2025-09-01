# frozen_string_literal: true

class UpdateConfigTool < ApplicationMCPTool
  tool_name "update_config"
  description "Update application configuration"

  property :config, type: "object", description: "Configuration object with nested settings", required: true

  def perform
    render text: "Updated config: database.host=#{config['database']['host']}"
  end
end

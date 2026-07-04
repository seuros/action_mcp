# frozen_string_literal: true

namespace :action_mcp do
  namespace :apps do
    desc "Print registered tool schemas as JSON (consumed by @action-mcp/vite-plugin for types.d.ts)"
    task schema: :environment do
      Rails.application.eager_load!

      tools = ActionMCP::ToolsRegistry.non_abstract.sort_by(&:name).map do |tool|
        tool.klass.to_h(protocol_version: ActionMCP.configuration.protocol_version)
             .slice(:name, :description, :inputSchema, :outputSchema)
      end

      puts JSON.generate({ tools: tools })
    end
  end
end

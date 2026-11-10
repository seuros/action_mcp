# frozen_string_literal: true

module ActionMCP
  # = Action MCP \Callbacks
  #
  # Hooks around the +perform+ method of tools and prompts:
  # <tt>before_perform</tt>, <tt>around_perform</tt> and <tt>after_perform</tt>.
  #
  #   class AnalyzeCsvTool < ApplicationMCPTool
  #     property :filepath, type: "string", description: "Path to CSV file"
  #
  #     before_perform do |mcp|
  #       Rails.logger.info("Starting CSV analysis for: #{mcp.filepath}")
  #     end
  #
  #     around_perform do |mcp, block|
  #       started = Time.current
  #       block.call
  #       Rails.logger.info("Analysis took #{Time.current - started}s")
  #     end
  #
  #     after_perform do |mcp|
  #       Rails.logger.info("Finished CSV analysis for: #{mcp.filepath}")
  #     end
  #   end
  #
  # A callback that halts the chain skips the after callbacks.
  Callbacks = LifecycleCallbacks.for(:perform)
end

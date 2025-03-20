# frozen_string_literal: true

require "active_support/callbacks"
require "active_support/core_ext/module/attribute_accessors"

module ActionMCP
  # = Action MCP \Callbacks
  #
  # Action MCP provides hooks during the life cycle of a message, command, or process.
  # Callbacks allow you to trigger logic during this cycle. Available callbacks are:
  #
  # * <tt>before_perform</tt>
  # * <tt>around_perform</tt>
  # * <tt>after_perform</tt>
  module Callbacks
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    class << self
      include ActiveSupport::Callbacks
      define_callbacks :execute
    end

    included do
      define_callbacks :perform, skip_after_callbacks_if_terminated: true
    end

    # These methods will be included into any Action MCP capability, adding
    # callbacks for the +perform+ method.
    class_methods do
      # Defines a callback that will get called right before the
      # object's perform method is executed.
      #
      #   class AnalyzeCsvTool < ApplicationMCPTool
      #     description "Analyze a CSV file"
      #
      #     property :filepath, type: "string", description: "Path to CSV file"
      #     collection :operations, type: "string", description: "Operations to perform"
      #
      #     validates :operations, inclusion: { in: %w[sum average count] }
      #
      #     before_perform do |mcp|
      #       Rails.logger.info("Starting CSV analysis for: #{mcp.filepath}")
      #     end
      #
      #     def perform
      #       result = operations.to_h { |op| [ op, rand(1..100) ] }
      #       render text: result.to_json
      #     end
      #   end
      #
      def before_perform(*filters, &blk)
        set_callback(:perform, :before, *filters, &blk)
      end

      # Defines a callback that will get called right after the
      # object's perform method has finished.
      #
      #   class GreetingPrompt < ApplicationMCPPrompt
      #     description "Generates a personalized greeting message"
      #
      #     argument :name, description: "The name to greet", required: true
      #     argument :style, description: "Style of greeting", enum: %w[formal casual friendly], default: "friendly"
      #
      #     after_perform do |mcp|
      #       Rails.logger.info("Generated #{mcp.style} greeting for #{mcp.name}")
      #     end
      #
      #     def perform
      #       render text: "Please create a greeting for #{name}"
      #       render text: "I'd be happy to create a #{style} greeting for #{name}!", role: "assistant"
      #       render text: "The greeting should be in #{style} style."
      #     end
      #   end
      #
      def after_perform(*filters, &blk)
        set_callback(:perform, :after, *filters, &blk)
      end

      # Defines a callback that will get called around the object's perform method.
      #
      #   class AnalyzeCsvTool < ApplicationMCPTool
      #     description "Analyze a CSV file"
      #
      #     property :filepath, type: "string", description: "Path to CSV file"
      #     collection :operations, type: "string", description: "Operations to perform"
      #
      #     validates :operations, inclusion: { in: %w[sum average count] }
      #
      #     around_perform do |mcp, block|
      #       start_time = Time.current
      #       Rails.logger.info("Starting CSV analysis for: #{mcp.filepath}")
      #       block.call
      #       duration = Time.current - start_time
      #       Rails.logger.info("Completed CSV analysis in #{duration}s")
      #     end
      #
      #     def perform
      #       result = operations.to_h { |op| [ op, rand(1..100) ] }
      #       render text: result.to_json
      #     end
      #   end
      #
      # You can access the return value of the perform only if the execution wasn't halted.
      #
      #   class GreetingPrompt < ApplicationMCPPrompt
      #     around_perform do |mcp, block|
      #       value = block.call
      #       puts value # => Result of render operations
      #     end
      #
      #     def perform
      #       render text: "Hello #{name}!"
      #     end
      #   end
      #
      def around_perform(*filters, &blk)
        set_callback(:perform, :around, *filters, &blk)
      end
    end
  end
end

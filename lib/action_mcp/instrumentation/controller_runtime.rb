# frozen_string_literal: true

require "active_support/core_ext/module/attr_internal"

module ActionMCP
  module Instrumentation
    module ControllerRuntime
      extend ActiveSupport::Concern

      protected

      attr_internal :mcp_runtime

      def cleanup_view_runtime
        mcp_rt_before_render = LogSubscriber.reset_runtime
        runtime = super
        mcp_rt_after_render = LogSubscriber.reset_runtime
        self.mcp_runtime = mcp_rt_before_render + mcp_rt_after_render
        runtime - mcp_rt_after_render
      end

      def append_info_to_payload(payload)
        super
        payload[:mcp_runtime] = (mcp_runtime || 0) + LogSubscriber.reset_runtime
      end

      class_methods do
        def log_process_action(payload)
          messages = super
          mcp_runtime = payload[:mcp_runtime]
          messages << (format("MCP: %.1fms", mcp_runtime.to_f)) if mcp_runtime
          messages
        end
      end
    end
  end
end

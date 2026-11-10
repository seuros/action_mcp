# frozen_string_literal: true

module ActionMCP
  # = Action MCP Resource Template \Callbacks
  #
  # Hooks around the +resolve+ method of resource templates:
  # <tt>before_resolve</tt>, <tt>around_resolve</tt> and <tt>after_resolve</tt>.
  #
  #   class OrdersTemplate < ApplicationMCPResTemplate
  #     uri_template "ecommerce://customers/{customer_id}/orders/{order_id}"
  #
  #     before_resolve do |template|
  #       Rails.logger.info("Resolving order #{template.order_id}")
  #     end
  #
  #     around_resolve do |template, block|
  #       resource = block.call
  #       Rails.logger.info("Order #{template.order_id} not found") unless resource
  #       resource
  #     end
  #
  #     after_resolve do |template|
  #       Rails.logger.info("Resolved order #{template.order_id}")
  #     end
  #   end
  #
  # The around callback receives the value returned by +resolve+.
  ResourceCallbacks = LifecycleCallbacks.for(:resolve)
end

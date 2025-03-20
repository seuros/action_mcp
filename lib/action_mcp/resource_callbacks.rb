# frozen_string_literal: true

require "active_support/callbacks"
require "active_support/core_ext/module/attribute_accessors"

module ActionMCP
  # = Action MCP Resource Template \Callbacks
  #
  # Action MCP Resource Template Callbacks provide hooks during the resource resolution lifecycle.
  # These callbacks allow you to trigger logic during the resource resolution process.
  # Available callbacks are:
  #
  # * <tt>before_resolve</tt>
  # * <tt>around_resolve</tt>
  # * <tt>after_resolve</tt>
  module ResourceCallbacks
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    class << self
      include ActiveSupport::Callbacks
      define_callbacks :execute
    end

    included do
      define_callbacks :resolve, skip_after_callbacks_if_terminated: true
    end

    # These methods will be included into any Action MCP Resource Template object, adding
    # callbacks for the +resolve+ method.
    class_methods do
      # Defines a callback that will get called right before the
      # resource template's resolve method is executed.
      #
      #   class OrdersTemplate < ApplicationMCPResTemplate
      #     description "Access order information"
      #     uri_template "ecommerce://customers/{customer_id}/orders/{order_id}"
      #     mime_type "application/json"
      #
      #     parameter :customer_id,
      #               description: "Customer identifier",
      #               required: true
      #     parameter :order_id,
      #               description: "Order identifier",
      #               required: true
      #
      #     before_resolve do |template|
      #       Rails.logger.info("Starting to resolve order: #{template.order_id} for customer: #{template.customer_id}")
      #     end
      #
      #     def resolve
      #       order = MockOrder.find_by(id: order_id)
      #       return unless order
      #
      #       ActionMCP::Resource.new(
      #         uri: "ecommerce://orders/#{order_id}",
      #         name: "Order #{order_id}",
      #         description: "Order information for order #{order_id}",
      #         mime_type: "application/json",
      #         size: order.to_json.length
      #       )
      #     end
      #   end
      #
      def before_resolve(*filters, &blk)
        set_callback(:resolve, :before, *filters, &blk)
      end

      # Defines a callback that will get called right after the
      # resource template's resolve method has finished.
      #
      #   class OrdersTemplate < ApplicationMCPResTemplate
      #     description "Access order information"
      #     uri_template "ecommerce://customers/{customer_id}/orders/{order_id}"
      #     mime_type "application/json"
      #
      #     parameter :customer_id,
      #               description: "Customer identifier",
      #               required: true
      #     parameter :order_id,
      #               description: "Order identifier",
      #               required: true
      #
      #     after_resolve do |template|
      #       Rails.logger.info("Finished resolving order resource for order: #{template.order_id}")
      #     end
      #
      #     def resolve
      #       order = MockOrder.find_by(id: order_id)
      #       return unless order
      #
      #       ActionMCP::Resource.new(
      #         uri: "ecommerce://orders/#{order_id}",
      #         name: "Order #{order_id}",
      #         description: "Order information for order #{order_id}",
      #         mime_type: "application/json",
      #         size: order.to_json.length
      #       )
      #     end
      #   end
      #
      def after_resolve(*filters, &blk)
        set_callback(:resolve, :after, *filters, &blk)
      end

      # Defines a callback that will get called around the resource template's resolve method.
      #
      #   class OrdersTemplate < ApplicationMCPResTemplate
      #     description "Access order information"
      #     uri_template "ecommerce://customers/{customer_id}/orders/{order_id}"
      #     mime_type "application/json"
      #
      #     parameter :customer_id,
      #               description: "Customer identifier",
      #               required: true
      #     parameter :order_id,
      #               description: "Order identifier",
      #               required: true
      #
      #     around_resolve do |template, block|
      #       start_time = Time.current
      #       Rails.logger.info("Starting resolution for order: #{template.order_id}")
      #
      #       resource = block.call
      #
      #       if resource
      #         Rails.logger.info("Order #{template.order_id} resolved successfully in #{Time.current - start_time}s")
      #       else
      #         Rails.logger.info("Order #{template.order_id} not found")
      #       end
      #
      #       resource
      #     end
      #
      #     def resolve
      #       order = MockOrder.find_by(id: order_id)
      #       return unless order
      #
      #       ActionMCP::Resource.new(
      #         uri: "ecommerce://orders/#{order_id}",
      #         name: "Order #{order_id}",
      #         description: "Order information for order #{order_id}",
      #         mime_type: "application/json",
      #         size: order.to_json.length
      #       )
      #     end
      #   end
      #
      # You can access the return value of the resolve method as shown above.
      #
      def around_resolve(*filters, &blk)
        set_callback(:resolve, :around, *filters, &blk)
      end
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  class RegistryBase
    class << self
      def items
        @items ||= {}
      end

      # Register an item by unique name
      def register(name, item_class)
        raise ArgumentError, "Name can't be blank" if name.blank?
        raise ArgumentError, "Name '#{name}' is already registered." if items.key?(name)

        items[name] = { class: item_class, enabled: true }
      end

      # Fetch an item’s metadata
      # Returns { class: <Class>, enabled: <Boolean> } or nil
      def fetch(name)
        items[name]
      end

      # Number of registered items, ignoring abstract ones.
      def size
        items.values.reject { |item| abstract_item?(item) }.size
      end

      def unregister(name)
        items.delete(name)
      end

      def clear!
        items.clear
      end

      # List of currently available items, excluding abstract ones.
      def enabled
        items
          .reject { |_name, item| item[:class].abstract? }
          .select { |_name, item| item[:enabled] }
      end

      def fetch_available_tool(name)
        enabled[name]&.fetch(:class)
      end

      # Enable an item by name
      def enable(name)
        raise ArgumentError, "Name '#{name}' not found." unless items.key?(name)

        items[name][:enabled] = true
      end

      # Disable an item by name
      def disable(name)
        raise ArgumentError, "Name '#{name}' not found." unless items.key?(name)

        items[name][:enabled] = false
      end

      private

      # Helper to determine if an item is abstract.
      def abstract_item?(item)
        klass = item[:class]
        klass.respond_to?(:abstract?) && klass.abstract?
      end
    end
  end
end

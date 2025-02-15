# frozen_string_literal: true

module ActionMCP
  class RegistryBase
    class NotFound < StandardError; end

    class << self
      def items
        @items ||= {}
      end

      # Register an item by unique name.
      def register(name, klass)
        raise ArgumentError, "Name can't be blank" if name.blank?
        raise ArgumentError, "Name '#{name}' is already registered." if items.key?(name)

        items[name] = { klass: klass, enabled: true }
      end

      # Retrieve an item’s metadata by name.
      def find(name)
        item = items[name]
        raise NotFound, "Item '#{name}' not found." if item.nil?

        item[:klass]
      end

      # Return the number of registered items, ignoring abstract ones.
      def size
        items.values.reject { |item| abstract_item?(item) }.size
      end

      def unregister(name)
        items.delete(name)
      end

      def clear!
        items.clear
      end

      # Chainable scope: returns only enabled, non-abstract items.
      def enabled
        RegistryScope.new(items)
      end

      private

      # Helper to determine if an item is abstract.
      def abstract_item?(item)
        klass = item[:klass]
        klass.respond_to?(:abstract?) && klass.abstract?
      end
    end

    # Query object for chainable registry scopes.
    class RegistryScope
      include Enumerable

      # Using a Data type for items.
      Item = Data.define(:name, :klass)

      def initialize(items)
        @items = items.reject do |_name, item|
          RegistryBase.send(:abstract_item?, item) || !item[:enabled]
        end.map { |name, item| Item.new(name, item[:klass]) }
      end

      def each(&)
        @items.each(&)
      end

      # Returns the names (keys) of all enabled items.
      def keys
        @items.map(&:name)
      end

      # Chainable finder for available tools by name.
      def find_available_tool(name)
        item = @items.find { |i| i.name == name }
        item&.klass
      end
    end
  end
end

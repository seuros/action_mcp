# frozen_string_literal: true

module ActionMCP
  # Base class for registries.
  class RegistryBase
    # Error raised when an item is not found in the registry.
    class NotFound < StandardError; end

    class << self
      # Returns all registered items.
      #
      # @return [Hash] A hash of registered items.
      def items
        @items = item_klass.descendants.each_with_object({}) do |klass, hash|
          next if klass.abstract?

          hash[klass.capability_name] = klass
        end
      end

      # Retrieve an item by name.
      #
      # @param name [String] The name of the item to find.
      # @raise [NotFound] if the item is not found.
      # @return [Class] The class of the item.
      def find(name)
        item = items[name]
        raise NotFound, "Item '#{name}' not found." if item.nil?

        item
      end

      # Return the number of registered items, ignoring abstract ones.
      #
      # @return [Integer] The number of registered items.
      def size
        items.size
      end

      # Chainable scope: returns only non-abstract items.
      #
      # @return [RegistryScope] A RegistryScope instance.
      def non_abstract
        RegistryScope.new(items)
      end

      private

      # Helper to determine if an item is abstract.
      #
      # @param klass [Class] The class to check.
      # @return [Boolean] True if the class is abstract, false otherwise.
      def abstract_item?(klass)
        klass.respond_to?(:abstract?) && klass.abstract?
      end

      def item_klass
        raise NotImplementedError, "Implement in subclass"
      end
    end

    # Query object for chainable registry scopes.
    class RegistryScope
      include Enumerable

      # Using a Data type for items.
      Item = Data.define(:name, :klass)

      # Initializes a new RegistryScope instance.
      #
      # @param items [Hash] The items to scope.
      # @return [void]
      def initialize(items)
        @items = items.reject do |_name, klass|
          RegistryBase.send(:abstract_item?, klass)
        end.map { |name, klass| Item.new(name, klass) }
      end

      # Iterates over the items in the scope.
      #
      # @yield [Item] The item to yield.
      # @return [void]
      def each(&)
        @items.each(&)
      end

      # Returns the names (keys) of all non-abstract items.
      #
      # @return [Array<String>] The names of all non-abstract items.
      def keys
        @items.map(&:name)
      end

      # Chainable finder for available tools by name.
      #
      # @param name [String] The name of the tool to find.
      # @return [Class, nil] The class of the tool, or nil if not found.
      def find_available_tool(name)
        item = @items.find { |i| i.name == name }
        item&.klass
      end
    end
  end
end

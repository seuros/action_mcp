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
        @items ||= {}
      end

      # Register an item by unique name.
      #
      # @param name [String] The unique name of the item.
      # @param klass [Class] The class of the item.
      # @raise [ArgumentError] if the name is blank or already registered.
      # @return [void]
      def register(name, klass)
        raise ArgumentError, "Name can't be blank" if name.blank?
        raise ArgumentError, "Name '#{name}' is already registered." if items.key?(name)

        items[name] = { klass: klass, enabled: true }
      end

      # Retrieve an item’s metadata by name.
      #
      # @param name [String] The name of the item to find.
      # @raise [NotFound] if the item is not found.
      # @return [Class] The class of the item.
      def find(name)
        item = items[name]
        raise NotFound, "Item '#{name}' not found." if item.nil?

        item[:klass]
      end

      # Return the number of registered items, ignoring abstract ones.
      #
      # @return [Integer] The number of registered items.
      def size
        items.values.reject { |item| abstract_item?(item) }.size
      end

      # Unregister an item by name.
      #
      # @param name [String] The name of the item to unregister.
      # @return [void]
      def unregister(name)
        items.delete(name)
      end

      # Clear all registered items.
      #
      # @return [void]
      def clear!
        items.clear
      end

      # Chainable scope: returns only enabled, non-abstract items.
      #
      # @return [RegistryScope] A RegistryScope instance.
      def enabled
        RegistryScope.new(items)
      end

      alias_method :all, :enabled

      private

      # Helper to determine if an item is abstract.
      #
      # @param item [Hash] The item to check.
      # @return [Boolean] True if the item is abstract, false otherwise.
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

      # Initializes a new RegistryScope instance.
      #
      # @param items [Hash] The items to scope.
      # @return [void]
      def initialize(items)
        @items = items.reject do |_name, item|
          RegistryBase.send(:abstract_item?, item) || !item[:enabled]
        end.map { |name, item| Item.new(name, item[:klass]) }
      end

      # Iterates over the items in the scope.
      #
      # @yield [Item] The item to yield.
      # @return [void]
      def each(&)
        @items.each(&)
      end

      # Returns the names (keys) of all enabled items.
      #
      # @return [Array<String>] The names of all enabled items.
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

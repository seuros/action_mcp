# frozen_string_literal: true

# Runs each test against an empty registry, then restores every non-abstract
# descendant of the base class plus whatever the registry held before.
module RegistryIsolation
  extend ActiveSupport::Concern

  class_methods do
    def isolate_registry(registry, base_class)
      setup do
        @original_registry_items = registry.items.dup
        registry.clear!
      end

      teardown do
        registry.clear!
        base_class.descendants.each { |klass| registry.register(klass) unless klass.abstract? }
        @original_registry_items.each { |name, klass| registry.items[name] ||= klass }
      end
    end
  end
end

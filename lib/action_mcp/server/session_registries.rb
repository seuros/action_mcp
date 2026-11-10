# frozen_string_literal: true

module ActionMCP
  module Server
    # Per-session tool, prompt and resource-template registries shared by the
    # in-memory BaseSession and the ActiveRecord Session. A registry of ["*"]
    # exposes everything the active profile allows.
    module SessionRegistries
      Kind = Data.define(:registry, :lookup, :name_method, :filtered, :list)

      KINDS = {
        tool: Kind.new(:tool_registry, "ActionMCP::ToolsRegistry", :tool_name, :filtered_tools, "tools"),
        prompt: Kind.new(:prompt_registry, "ActionMCP::PromptsRegistry", :prompt_name, :filtered_prompts, "prompts"),
        resource_template: Kind.new(:resource_registry, "ActionMCP::ResourceTemplatesRegistry", :capability_name,
                                    :filtered_resources, "resources")
      }.freeze

      WILDCARD = [ "*" ].freeze

      def initialize!
        return false unless status == "initializing" && !initialized?

        self.initialized = true
        self.status = "initialized"
        save
      end

      def send_progress_notification(progressToken:, progress:, total: nil, message: nil)
        ActionMCP::Server::TransportHandler.new(self).send_progress_notification(
          progressToken: progressToken, progress: progress, total: total, message: message
        )
      end

      { tool: "tools", prompt: "prompts", resource_template: "resource_templates" }.each do |kind, plural|
        define_method(:"register_#{kind}") { |class_or_name| register_capability(kind, class_or_name) }
        define_method(:"unregister_#{kind}") { |class_or_name| unregister_capability(kind, class_or_name) }
        define_method(:"registered_#{plural}") { registered_capabilities(kind) }
      end

      { tools: :tool, prompts: :prompt, resources: :resource_template }.each do |suffix, kind|
        define_method(:"uses_all_#{suffix}?") { uses_all?(kind) }
      end

      private

      KINDS.each_value do |kind|
        define_method(:"send_#{kind.list}_list_changed_notification") do
          return unless server_capabilities.dig(kind.list, "listChanged")

          write(JSON_RPC::Notification.new(method: "notifications/#{kind.list}/list_changed"))
        end
      end

      def register_capability(kind, class_or_name)
        name = normalize_name(class_or_name, kind)
        return false unless capability_exists?(kind, name)
        return true if uses_all?(kind)

        names = registry_names(kind)
        unless names.include?(name)
          names << name
          save!
          send("send_#{KINDS[kind].list}_list_changed_notification")
        end
        true
      end

      def unregister_capability(kind, class_or_name)
        name = normalize_name(class_or_name, kind)

        if uses_all?(kind)
          return unless capability_exists?(kind, name)

          expand_registry!(kind)
        end

        return unless registry_names(kind).delete(name)

        save!
        send("send_#{KINDS[kind].list}_list_changed_notification")
      end

      def registered_capabilities(kind)
        return ActionMCP.configuration.public_send(KINDS[kind].filtered).map(&:klass) if uses_all?(kind)

        (public_send(KINDS[kind].registry) || []).filter_map do |name|
          registry_for(kind).find(name)
        rescue StandardError
          nil
        end
      end

      def uses_all?(kind)
        public_send(KINDS[kind].registry) == WILDCARD
      end

      def registry_names(kind)
        public_send(KINDS[kind].registry) || public_send(:"#{KINDS[kind].registry}=", [])
      end

      # Replaces the wildcard with the explicit names it stood for, so one entry can be removed.
      def expand_registry!(kind)
        names = ActionMCP.configuration.public_send(KINDS[kind].filtered).map(&:name)
        public_send(:"#{KINDS[kind].registry}=", names)
      end

      def capability_exists?(kind, name)
        registry_for(kind).find(name)
        true
      rescue ActionMCP::RegistryBase::NotFound
        false
      end

      def registry_for(kind)
        KINDS[kind].lookup.constantize
      end

      def normalize_name(class_or_name, kind)
        case class_or_name
        when String then class_or_name
        when Class then class_or_name.public_send(KINDS[kind].name_method)
        else raise ArgumentError, "Expected String or Class, got #{class_or_name.class}"
        end
      end
    end
  end
end

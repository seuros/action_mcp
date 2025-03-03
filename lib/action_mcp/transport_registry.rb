module ActionMCP
  # lib/transport_registry.rb
  module TransportRegistry
    extend self

    def create(transport)
      Rails.logger.info "Adding transport for session: #{transport.session_id}"

      # Store the transport in the globally shared registry (initialized in an initializer)
      registry[transport.session_id] = transport

      log_registry_state
    end

    def destroy(session_id)
      Rails.logger.info "Removing transport for session: #{session_id}"

      # Remove the transport from the shared registry
      registry.delete(session_id)

      log_registry_state
    rescue => e
      Rails.logger.error "Error removing transport: #{e.message}"
    end

    def find(session_id)
      return nil unless session_id

      transport = registry[session_id]

      if transport
        if transport.closed?
          destroy(session_id)
          return nil
        end
      else
        # If the session exists in the database but not in the registry, clean it up
        destroy(session_id)
        return nil
      end

      Rails.logger.info "Looking up session: #{session_id}, found: yes"
      transport
    end

    def delete_all
      # Clear the shared registry
      registry.clear
    end

    private

    def registry
      ActionMCP.transport_registry
    end

    def log_registry_state
      Rails.logger.info "Memory transports: #{registry.keys.join(', ')}"
      Rails.logger.info "Memory active transports count: #{registry.size}"
    rescue => e
      Rails.logger.error "Error logging registry state: #{e.message}"
    end
  end
end

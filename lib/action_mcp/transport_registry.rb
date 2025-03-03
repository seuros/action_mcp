module ActionMCP
  module TransportRegistry
    extend self

    def add(session_id, transport)
      Rails.logger.info "Adding transport for session: #{session_id}"

      # Store the transport in the globally shared registry (initialized in an initializer)
      registry[session_id] = transport

      log_registry_state
    end

    def remove(session_id)
      Rails.logger.info "Removing transport for session: #{session_id}"

      # Mark the session as inactive in the database
      SSESession.where(session_id: session_id).update_all(active: false)

      # Remove the transport from the shared registry
      registry.delete(session_id)

      log_registry_state
    rescue => e
      Rails.logger.error "Error removing transport: #{e.message}"
    end

    def get(session_id)
      return nil unless session_id

      session = SSESession.find_or_create_by(session_id: session_id)
      unless session
        Rails.logger.info "Session not found: #{session_id} after lookup"
        return nil
      end

      transport = registry[session_id]

      if transport
        if transport.closed?
          remove(session_id)
          return nil
        end

        # Update the last ping time in the database
        session.touch(:last_ping_at)
      else
        # If the session exists in the database but not in the registry, clean it up
        remove(session_id)
        return nil
      end

      Rails.logger.info "Looking up session: #{session_id}, found: yes"
      transport
    end

    def clear
      # Mark all sessions as inactive in the database
      SSESession.update_all(active: false)

      # Clear the shared registry
      registry.clear
    end

    private

    # Use the registry defined in an initializer (e.g., Rails.application.config.transport_registry = Concurrent::Map.new)
    def registry
      ActionMCP.transport_registry
    end

    def log_registry_state
      Rails.logger.info "Memory transports: #{registry.keys.join(', ')}"
      Rails.logger.info "Database active sessions count: #{SSESession.where(active: true).count}"
      Rails.logger.info "Memory active transports count: #{registry.size}"
    rescue => e
      Rails.logger.error "Error logging registry state: #{e.message}"
    end
  end
end

# frozen_string_literal: true

module ActionMCP
  module Generators
    class IdentifierGenerator < Rails::Generators::Base
      namespace "action_mcp:identifier"
      source_root File.expand_path("templates", __dir__)
      desc "Creates a Gateway Identifier for authentication patterns"

      argument :name, type: :string, required: true, banner: "IdentifierName"

      class_option :auth_method, type: :string, required: true,
                   desc: "Authentication method name (e.g., 'api_key', 'session', 'custom')"
      class_option :identity, type: :string, default: "user",
                   desc: "Identity type this identifier provides (e.g., 'user', 'admin')"
      class_option :lookup_method, type: :string, default: "database",
                   desc: "How to resolve identity: 'database', 'middleware', 'headers', 'custom'"

      def create_identifier_file
        template "identifier.rb.erb", "app/mcp/identifiers/#{file_name}.rb"
      end

      def show_usage_instructions
        say "\nIdentifier generated successfully!", :green
        say "\nNext steps:", :blue
        say "1. Configure authentication methods in config/mcp.yml:"
        say "   authentication_methods: [\"#{auth_method}\"]", :yellow
        say "\n2. Register in ApplicationGateway:"
        say "   identified_by #{class_name}", :yellow
        say "\n3. Customize the resolve method in app/mcp/identifiers/#{file_name}.rb"

        if lookup_method == "database"
          say "\n4. Ensure your #{identity.capitalize} model has the required fields/methods", :cyan
        elsif lookup_method == "middleware"
          say "\n4. Ensure your middleware sets the required request.env keys", :cyan
        end
      end

      private

      def class_name
        "#{name.camelize}#{name.camelize.end_with?('Identifier') ? '' : 'Identifier'}"
      end

      def file_name
        base = name.underscore
        base.end_with?("_identifier") ? base : "#{base}_identifier"
      end

      def auth_method
        options[:auth_method]
      end

      def identity
        options[:identity]
      end

      def lookup_method
        options[:lookup_method]
      end

      def resolve_implementation
        case lookup_method
        when "database"
          database_lookup_implementation
        when "middleware"
          middleware_lookup_implementation
        when "headers"
          headers_lookup_implementation
        else
          custom_lookup_implementation
        end
      end

      def database_lookup_implementation
        case auth_method
        when /api_key|token/
          api_key_database_lookup
        when /session/
          session_database_lookup
        else
          generic_database_lookup
        end
      end

      def api_key_database_lookup
        <<~RUBY.indent(4)
          # Extract API key from various sources
          api_key = extract_api_key
          raise Unauthorized, "Missing API key" unless api_key

          # Look up #{identity} by API key
          #{identity} = #{identity.capitalize}.find_by(api_key: api_key)
          raise Unauthorized, "Invalid API key" unless #{identity}

          # Optional: Add additional validation
          # raise Unauthorized, "#{identity.capitalize} account inactive" unless #{identity}.active?

          #{identity}
        RUBY
      end

      def session_database_lookup
        <<~RUBY.indent(4)
          # Get #{identity} ID from session
          #{identity}_id = session&.[]('#{identity}_id')
          raise Unauthorized, "No #{identity} session" unless #{identity}_id

          # Look up #{identity} in database
          #{identity} = #{identity.capitalize}.find_by(id: #{identity}_id)
          raise Unauthorized, "Invalid session" unless #{identity}

          #{identity}
        RUBY
      end

      def generic_database_lookup
        <<~RUBY.indent(4)
          # TODO: Extract identifier from request (headers, params, etc.)
          identifier = nil # Implement your extraction logic here
          raise Unauthorized, "Missing authentication identifier" unless identifier

          # Look up #{identity} in database
          #{identity} = #{identity.capitalize}.find_by(some_field: identifier)
          raise Unauthorized, "Authentication failed" unless #{identity}

          #{identity}
        RUBY
      end

      def middleware_lookup_implementation
        <<~RUBY.indent(4)
          # Get #{identity} from middleware (Warden, Devise, etc.)
          #{identity} = user_from_middleware
          raise Unauthorized, "No authenticated #{identity} found" unless #{identity}

          # Optional: Add additional validation
          # raise Unauthorized, "#{identity.capitalize} access denied" unless #{identity}.can_access_mcp?

          #{identity}
        RUBY
      end

      def headers_lookup_implementation
        <<~RUBY.indent(4)
          # Extract #{identity} info from request headers
          #{identity}_id = @request.env['HTTP_X_#{identity.upcase}_ID']
          raise Unauthorized, "#{identity.capitalize} ID header missing" unless #{identity}_id

          # Optional: Get additional info from headers
          email = @request.env['HTTP_X_#{identity.upcase}_EMAIL']
          roles = @request.env['HTTP_X_#{identity.upcase}_ROLES']&.split(',') || []

          # Option 1: Look up in database
          #{identity} = #{identity.capitalize}.find(#{identity}_id)
        #{'  '}
          # Option 2: Create simple object from headers (no DB lookup)
          # #{identity} = OpenStruct.new(
          #   id: #{identity}_id,
          #   email: email,
          #   roles: roles
          # )

          #{identity}
        rescue ActiveRecord::RecordNotFound
          raise Unauthorized, "Invalid #{identity}"
        RUBY
      end

      def custom_lookup_implementation
        <<~RUBY.indent(4)
          # TODO: Implement your custom authentication logic here

          # Example patterns:
          # 1. Extract credentials from request
          # credentials = extract_credentials_from_request

          # 2. Validate credentials (API call, database lookup, etc.)
          # #{identity} = validate_credentials(credentials)

          # 3. Return the authenticated #{identity} or raise Unauthorized
          # raise Unauthorized, "Authentication failed" unless #{identity}

          raise NotImplementedError, "Custom authentication logic not implemented"
        RUBY
      end
    end
  end
end

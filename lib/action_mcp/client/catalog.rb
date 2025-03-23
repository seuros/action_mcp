# frozen_string_literal: true

module ActionMCP
  module Client
    # Catalog
    #
    # A collection that manages and provides access to resources.
    # This class stores resource definitions and provides methods for
    # retrieving, filtering, and accessing resources by URI or other attributes.
    #
    # Example usage:
    #   resources_data = client.list_resources # Returns array of resource definitions
    #   catalog = Catalog.new(resources_data)
    #
    #   # Access a specific resource by URI
    #   main_file = catalog.find_by_uri("file:///project/src/main.rs")
    #
    #   # Get all resources matching a criteria
    #   rust_files = catalog.filter { |r| r.mime_type == "text/x-rust" }
    #
    class Catalog
      # Initialize a new Catalog with resource definitions
      #
      # @param resources [Array<Hash>] Array of resource definition hashes, each containing
      #   uri, name, description, and mimeType keys
      def initialize(resources = [])
        @resources = resources.map { |resource_data| Resource.new(resource_data) }
      end

      # Return all resources in the collection
      #
      # @return [Array<Resource>] All resource objects in the collection
      def all
        @resources
      end

      # Find a resource by URI
      #
      # @param uri [String] URI of the resource to find
      # @return [Resource, nil] The resource with the given URI, or nil if not found
      def find_by_uri(uri)
        @resources.find { |resource| resource.uri == uri }
      end

      # Find resources by name
      #
      # @param name [String] Name of the resources to find
      # @return [Array<Resource>] Resources with the given name
      def find_by_name(name)
        @resources.select { |resource| resource.name == name }
      end

      # Find resources by MIME type
      #
      # @param mime_type [String] MIME type to search for
      # @return [Array<Resource>] Resources with the given MIME type
      def find_by_mime_type(mime_type)
        @resources.select { |resource| resource.mime_type == mime_type }
      end

      # Filter resources based on a given block
      #
      # @yield [resource] Block that determines whether to include a resource
      # @yieldparam resource [Resource] A resource from the collection
      # @yieldreturn [Boolean] true to include the resource, false to exclude it
      # @return [Array<Resource>] Resources that match the filter criteria
      def filter(&block)
        @resources.select(&block)
      end

      # Get a list of all resource URIs
      #
      # @return [Array<String>] URIs of all resources in the collection
      def uris
        @resources.map(&:uri)
      end

      # Number of resources in the collection
      #
      # @return [Integer] The number of resources
      def size
        @resources.size
      end

      # Check if the collection contains a resource with the given URI
      #
      # @param uri [String] The resource URI to check for
      # @return [Boolean] true if a resource with the URI exists
      def contains_uri?(uri)
        @resources.any? { |resource| resource.uri == uri }
      end

      # Group resources by MIME type
      #
      # @return [Hash<String, Array<Resource>>] Hash mapping MIME types to arrays of resources
      def group_by_mime_type
        @resources.group_by(&:mime_type)
      end

      # Search resources by keyword in name or description
      #
      # @param keyword [String] Keyword to search for
      # @return [Array<Resource>] Resources matching the search term
      def search(keyword)
        keyword = keyword.downcase
        @resources.select do |resource|
          resource.name.downcase.include?(keyword) ||
            (resource.description && resource.description.downcase.include?(keyword))
        end
      end

      # Implements enumerable functionality for the collection
      include Enumerable

      # Yield each resource in the collection to the given block
      #
      # @yield [resource] Block to execute for each resource
      # @yieldparam resource [Resource] A resource from the collection
      # @return [Enumerator] If no block is given
      def each(&block)
        @resources.each(&block)
      end

      # Internal Resource class to represent individual resources
      class Resource
        attr_reader :uri, :name, :description, :mime_type

        # Initialize a new Resource instance
        #
        # @param data [Hash] Resource definition hash containing uri, name, description, and mimeType
        def initialize(data = [])
          @uri = data["uri"]
          @name = data["name"]
          @description = data["description"]
          @mime_type = data["mimeType"]
        end

        # Get the file extension from the resource name
        #
        # @return [String, nil] The file extension or nil if no extension
        def extension
          File.extname(@name)[1..-1] if @name.include?(".")
        end

        # Check if this resource is a text file based on MIME type
        #
        # @return [Boolean] true if the resource is a text file
        def text?
          @mime_type&.start_with?("text/")
        end

        # Check if this resource is an image based on MIME type
        #
        # @return [Boolean] true if the resource is an image
        def image?
          @mime_type&.start_with?("image/")
        end

        # Get the path portion of the URI
        #
        # @return [String, nil] The path component of the URI
        def path
          URI(@uri).path rescue nil
        end

        # Generate a hash representation of the resource
        #
        # @return [Hash] Hash containing resource details
        def to_h
          {
            "uri" => @uri,
            "name" => @name,
            "description" => @description,
            "mimeType" => @mime_type
          }
        end
      end
    end
  end
end

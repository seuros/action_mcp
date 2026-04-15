# frozen_string_literal: true

module ActionMCP
  # Represents a resource with its metadata.
  # Used by resources/list to describe concrete resources.
  class Resource
    attr_reader :uri, :name, :title, :description, :mime_type, :size, :annotations, :_meta

    # @param uri [String] The URI of the resource
    # @param name [String] Display name of the resource
    # @param title [String, nil] Human-readable title
    # @param description [String, nil] Description of the resource
    # @param mime_type [String, nil] MIME type of the resource content
    # @param size [Integer, nil] Size of the resource in bytes
    # @param annotations [Hash, nil] Optional annotations
    # @param _meta [Hash, nil] Optional _meta extension metadata
    def initialize(uri:, name:, title: nil, description: nil, mime_type: nil, size: nil, annotations: nil, _meta: nil)
      if _meta && !_meta.is_a?(Hash)
        raise ArgumentError, "_meta must be a Hash or nil, got: #{_meta.class}"
      end

      @uri = uri
      @name = name
      @title = title
      @description = description
      @mime_type = mime_type
      @size = size
      @annotations = annotations
      @_meta = _meta
      freeze
    end

    # Convert the resource to a hash with the keys expected by MCP.
    # Note: The key for mime_type is converted to 'mimeType' as specified.
    #
    # @return [Hash] A hash representation of the resource.
    def to_h
      hash = { uri: uri, name: name }
      hash[:title] = title if title
      hash[:description] = description if description
      hash[:mimeType] = mime_type if mime_type
      hash[:size] = size if size
      hash[:annotations] = annotations if annotations
      hash[:_meta] = _meta if _meta && !_meta.empty?
      hash
    end

    def to_json(*)
      MultiJson.dump(to_h, *)
    end

    def ==(other)
      other.is_a?(Resource) && uri == other.uri && name == other.name &&
        title == other.title && description == other.description &&
        mime_type == other.mime_type && size == other.size &&
        annotations == other.annotations && _meta == other._meta
    end
    alias eql? ==

    def hash
      [ uri, name, title, description, mime_type, size, annotations, _meta ].hash
    end
  end
end

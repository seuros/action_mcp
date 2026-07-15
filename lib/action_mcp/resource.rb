# frozen_string_literal: true

module ActionMCP
  # Represents a resource with its metadata.
  # Used by resources/list to describe concrete resources.
  class Resource
    attr_reader :uri, :name, :title, :description, :mime_type, :size, :annotations, :meta

    # @param uri [String] The URI of the resource
    # @param name [String] Display name of the resource
    # @param title [String, nil] Human-readable title
    # @param description [String, nil] Description of the resource
    # @param mime_type [String, nil] MIME type of the resource content
    # @param size [Integer, nil] Size of the resource in bytes
    # @param annotations [Hash, nil] Optional annotations
    # @param meta [Hash, #to_hash, #to_h, nil] Optional extension metadata. Emitted on the wire as `_meta`.
    def initialize(uri:, name:, title: nil, description: nil, mime_type: nil, size: nil, annotations: nil, meta: nil)
      raise ArgumentError, "uri must be a non-empty string" unless uri.is_a?(String) && uri.present?
      raise ArgumentError, "name must be a non-empty string" unless name.is_a?(String) && name.present?

      { title: title, description: description, mime_type: mime_type }.each do |field, value|
        raise ArgumentError, "#{field} must be a string or nil" unless value.nil? || value.is_a?(String)
      end
      unless size.nil? || (size.is_a?(Integer) && size >= 0)
        raise ArgumentError, "size must be a non-negative integer or nil"
      end

      @uri = uri
      @name = name
      @title = title
      @description = description
      @mime_type = mime_type
      @size = size
      @annotations = annotations.nil? ? nil : Content::Validation.copy_object!(annotations, "annotations")
      Content::Validation.validate_annotations!(@annotations)
      @meta = meta.nil? ? nil : Content::Validation.copy_object!(meta, "meta")
      to_h
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
      hash[:_meta] = meta if meta && !meta.empty?
      Content::Validation.validate_resource!(hash)
      hash
    end

    def to_json(*)
      MultiJson.dump(to_h, *)
    end

    def ==(other)
      other.is_a?(Resource) && uri == other.uri && name == other.name &&
        title == other.title && description == other.description &&
        mime_type == other.mime_type && size == other.size &&
        annotations == other.annotations && meta == other.meta
    end
    alias eql? ==

    def hash
      [ uri, name, title, description, mime_type, size, annotations, meta ].hash
    end
  end
end

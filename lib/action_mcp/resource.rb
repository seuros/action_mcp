# frozen_string_literal: true

module ActionMCP
  # Represents a resource with its metadata.
  Resource = Data.define(:uri, :name, :description, :mime_type, :size) do
    # Convert the resource to a hash with the keys expected by MCP.
    # Note: The key for mime_type is converted to 'mimeType' as specified.
    #
    # @return [Hash] A hash representation of the resource.
    def to_h
      hash = { uri: uri, name: name }
      hash[:description] = description if description
      hash[:mimeType]   = mime_type if mime_type
      hash[:size]       = size if size
      hash
    end

    def to_json(*)
      MultiJson.dump(to_h, *)
    end
  end
end

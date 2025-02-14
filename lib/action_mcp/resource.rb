# frozen_string_literal: true

module ActionMCP
  Resource = Data.define(:uri, :name, :description, :mime_type, :size) do
    # Convert the resource to a hash with the keys expected by MCP.
    # Note: The key for mime_type is converted to 'mimeType' as specified.
    def to_h
      hash = { uri: uri, name: name }
      hash[:description] = description if description
      hash[:mimeType]   = mime_type if mime_type
      hash[:size]       = size if size
      hash
    end

    # Convert the resource to a JSON string.
    def to_json(*args)
      MultiJson.dump(to_h, *args)
    end
  end
end

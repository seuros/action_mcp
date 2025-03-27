# frozen_string_literal: true

module ActionMCP
  class BaseResponse
    include Enumerable
    attr_reader :is_error

    def initialize
      @is_error = false
    end

    # Mark response as error
    def mark_as_error!(symbol = :invalid_request, message: nil, data: nil)
      @is_error = true
      @symbol = symbol
      @error_message = message
      @error_data = data
      self
    end

    # Convert to hash format expected by MCP protocol
    def to_h
      if @is_error
        JSON_RPC::JsonRpcError.new(@symbol, message: @error_message, data: @error_data).to_h
      else
        build_success_hash
      end
    end

    # Method to be implemented by subclasses
    def build_success_hash
      raise NotImplementedError, "Subclasses must implement #build_success_hash"
    end

    # Alias as_json to to_h for consistency
    alias as_json to_h

    # Handle to_json directly
    def to_json(options = nil)
      to_h.to_json(options)
    end

    # Compare with hash for easier testing
    def ==(other)
      case other
      when Hash
        # Convert both to normalized format for comparison
        hash_self = to_h.deep_transform_keys { |key| key.to_s.underscore }
        hash_other = other.deep_transform_keys { |key| key.to_s.underscore }
        hash_self == hash_other
      when self.class
        compare_with_same_class(other)
      else
        super
      end
    end

    # Method to be implemented by subclasses for comparison
    def compare_with_same_class(other)
      raise NotImplementedError, "Subclasses must implement #compare_with_same_class"
    end

    # Implement eql? for hash key comparison
    def eql?(other)
      self == other
    end

    # Method to be implemented by subclasses for hash generation
    def hash_components
      raise NotImplementedError, "Subclasses must implement #hash_components"
    end

    # Implement hash method for hash key usage
    def hash
      hash_components.hash
    end

    def success?
      !is_error
    end

    def error?
      is_error
    end
  end
end

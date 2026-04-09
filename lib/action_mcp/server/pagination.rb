# frozen_string_literal: true

module ActionMCP
  module Server
    # Shared cursor-based pagination for all list endpoints.
    #
    # Two strategies:
    #   1. Offset-based — for in-memory arrays (tools, prompts, resource templates).
    #   2. Keyset-based — for ActiveRecord relations (tasks). Stable under concurrent writes.
    #
    # When pagination_page_size is nil (default), returns all items
    # unless the caller passes force: true or the client sends a cursor.
    module Pagination
      DEFAULT_PAGE_SIZE = 10

      # Offset-based pagination for in-memory collections (tools, prompts, resources).
      # For ActiveRecord relations, use paginate_by_keyset instead.
      #
      # @param collection [Array] Items to paginate
      # @param cursor [String, nil] Opaque cursor from the client
      # @param page_size [Integer, nil] Override page size (nil = use config)
      # @param force [Boolean] Force pagination even when globally disabled
      # @return [Array(Array, String|nil)] [page_items, next_cursor_or_nil]
      def paginate(collection, cursor: nil, page_size: nil, force: false)
        effective_page_size = page_size || pagination_page_size
        items = Array(collection)

        return [ items, nil ] unless force || effective_page_size || cursor

        page_size = effective_page_size || DEFAULT_PAGE_SIZE
        offset = decode_offset_cursor(cursor)
        page = items.drop(offset).take(page_size + 1)

        has_more = page.size > page_size
        page = page.first(page_size) if has_more
        next_cursor = has_more ? encode_offset_cursor(offset + page_size) : nil

        [ page, next_cursor ]
      end

      # Keyset-based pagination for ActiveRecord relations.
      # Uses a single column as cursor (must be unique + ordered).
      # The relation MUST already be ordered by that column.
      #
      # @param relation [ActiveRecord::Relation] Ordered AR relation
      # @param cursor [String, nil] Opaque keyset cursor (Base64-encoded column value)
      # @param page_size [Integer] Page size
      # @param column [Symbol] Column to use as cursor key (default: :id)
      # @return [Array(Array, String|nil)] [page_items, next_cursor_or_nil]
      def paginate_by_keyset(relation, cursor: nil, page_size: DEFAULT_PAGE_SIZE, column: :id)
        if cursor
          value = decode_keyset_cursor(cursor)
          relation = relation.where(column => ...value)
        end

        page = relation.limit(page_size + 1).to_a
        has_more = page.size > page_size
        items = has_more ? page.first(page_size) : page
        next_cursor = has_more ? encode_keyset_cursor(items.last, column) : nil

        [ items, next_cursor ]
      end

      private

      def pagination_page_size
        ActionMCP.configuration.pagination_page_size
      end

      # --- Offset cursors (in-memory arrays) ---

      def decode_offset_cursor(cursor)
        return 0 if cursor.nil?
        raise CursorError, "Cursor must be a non-empty string" unless cursor.is_a?(String) && !cursor.empty?

        decoded = Base64.urlsafe_decode64(cursor)
        raise CursorError, "Invalid cursor format" unless decoded.match?(/\A\d+\z/)
        decoded.to_i
      rescue ArgumentError
        raise CursorError, "Invalid cursor encoding"
      end

      def encode_offset_cursor(offset)
        Base64.urlsafe_encode64(offset.to_s, padding: false)
      end

      # --- Keyset cursors (ActiveRecord) ---

      def decode_keyset_cursor(cursor)
        raise CursorError, "Cursor must be a non-empty string" unless cursor.is_a?(String) && !cursor.empty?
        Base64.urlsafe_decode64(cursor)
      rescue ArgumentError
        raise CursorError, "Invalid cursor encoding"
      end

      def encode_keyset_cursor(record, column)
        value = record.public_send(column)
        Base64.urlsafe_encode64(value.to_s, padding: false)
      end
    end

    # Raised when a client provides a malformed cursor.
    # Handlers catch this and return -32602 (Invalid params).
    class CursorError < StandardError; end
  end
end

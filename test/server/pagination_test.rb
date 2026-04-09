# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class PaginationTest < ActiveSupport::TestCase
      # Test harness that includes the Pagination module
      class PaginationHarness
        include ActionMCP::Server::Pagination
      end

      setup do
        @paginator = PaginationHarness.new
        @items = (1..25).to_a
      end

      # --- Offset-based pagination ---

      test "paginate returns all items when pagination is disabled and no cursor" do
        ActionMCP.configuration.pagination_page_size = nil
        items, next_cursor = @paginator.paginate(@items)

        assert_equal @items, items
        assert_nil next_cursor
      end

      test "paginate returns first page when enabled" do
        ActionMCP.configuration.pagination_page_size = 10
        items, next_cursor = @paginator.paginate(@items)

        assert_equal (1..10).to_a, items
        assert_not_nil next_cursor
      ensure
        ActionMCP.configuration.pagination_page_size = nil
      end

      test "paginate follows cursor to next page" do
        ActionMCP.configuration.pagination_page_size = 10
        _, first_cursor = @paginator.paginate(@items)
        items, next_cursor = @paginator.paginate(@items, cursor: first_cursor)

        assert_equal (11..20).to_a, items
        assert_not_nil next_cursor
      ensure
        ActionMCP.configuration.pagination_page_size = nil
      end

      test "paginate returns last page without nextCursor" do
        ActionMCP.configuration.pagination_page_size = 10
        _, c1 = @paginator.paginate(@items)
        _, c2 = @paginator.paginate(@items, cursor: c1)
        items, next_cursor = @paginator.paginate(@items, cursor: c2)

        assert_equal (21..25).to_a, items
        assert_nil next_cursor
      ensure
        ActionMCP.configuration.pagination_page_size = nil
      end

      test "paginate with page_size override" do
        items, next_cursor = @paginator.paginate(@items, page_size: 5, force: true)

        assert_equal (1..5).to_a, items
        assert_not_nil next_cursor
      end

      test "paginate with force: true ignores global setting" do
        ActionMCP.configuration.pagination_page_size = nil
        items, next_cursor = @paginator.paginate(@items, page_size: 10, force: true)

        assert_equal (1..10).to_a, items
        assert_not_nil next_cursor
      end

      test "paginate honors cursor even when pagination is disabled" do
        ActionMCP.configuration.pagination_page_size = nil
        # Manually create a cursor for offset 5
        cursor = Base64.urlsafe_encode64("5", padding: false)
        items, next_cursor = @paginator.paginate(@items, cursor: cursor)

        # Should return items from offset 5, using DEFAULT_PAGE_SIZE (10)
        assert_equal (6..15).to_a, items
        assert_not_nil next_cursor, "Should have nextCursor since 20 items remain but page size is 10"
      end

      test "paginate raises CursorError for malformed cursor" do
        assert_raises(CursorError) do
          @paginator.paginate(@items, cursor: "not-base64!!!", force: true)
        end
      end

      test "paginate raises CursorError for non-numeric cursor" do
        cursor = Base64.urlsafe_encode64("abc", padding: false)
        assert_raises(CursorError) do
          @paginator.paginate(@items, cursor: cursor, force: true)
        end
      end

      test "paginate raises CursorError for non-string cursor" do
        assert_raises(CursorError) do
          @paginator.paginate(@items, cursor: 123, force: true)
        end
      end

      test "paginate returns empty array for offset beyond collection" do
        cursor = Base64.urlsafe_encode64("999", padding: false)
        items, next_cursor = @paginator.paginate(@items, cursor: cursor, force: true)

        assert_equal [], items
        assert_nil next_cursor
      end

      test "paginate with exact page size boundary" do
        exact_items = (1..10).to_a
        items, next_cursor = @paginator.paginate(exact_items, page_size: 10, force: true)

        assert_equal exact_items, items
        assert_nil next_cursor
      end

      # --- Keyset-based pagination ---

      test "paginate_by_keyset raises CursorError for malformed cursor" do
        assert_raises(CursorError) do
          @paginator.paginate_by_keyset(
            ActionMCP::Session::Task.none,
            cursor: "garbage!!!"
          )
        end
      end

      test "paginate_by_keyset raises CursorError for empty cursor" do
        assert_raises(CursorError) do
          @paginator.paginate_by_keyset(
            ActionMCP::Session::Task.none,
            cursor: ""
          )
        end
      end

      # --- Config validation ---

      test "pagination_page_size rejects non-positive values" do
        assert_raises(ArgumentError) do
          ActionMCP.configuration.pagination_page_size = 0
        end

        assert_raises(ArgumentError) do
          ActionMCP.configuration.pagination_page_size = -5
        end

        assert_raises(ArgumentError) do
          ActionMCP.configuration.pagination_page_size = "abc"
        end
      end

      test "pagination_page_size accepts nil to disable" do
        ActionMCP.configuration.pagination_page_size = nil
        assert_nil ActionMCP.configuration.pagination_page_size
      end

      test "pagination_page_size accepts positive integer" do
        ActionMCP.configuration.pagination_page_size = 50
        assert_equal 50, ActionMCP.configuration.pagination_page_size
      ensure
        ActionMCP.configuration.pagination_page_size = nil
      end
    end
  end
end

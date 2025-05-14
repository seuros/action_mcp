# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module ActionMCP
  module Client
    class CollectionPaginationTest < ActiveSupport::TestCase
      include FixtureHelpers

      class TestCollection < Collection
        attr_accessor :current_page, :load_count, :fixture_data

        def initialize(client, fixture_data)
          super([], client)
          @current_page = 0
          @load_count = 0
          @load_method = :load_test_data
          @fixture_data = fixture_data
        end

        def reset
          @current_page = 0
          @load_count = 0
          @loaded = false
          @collection_data = []
          @next_cursor = nil
        end

        protected

        def load_items(force: false, timeout: DEFAULT_TIMEOUT)
          @load_count += 1
          # Load all data at once for regular load_items
          all_items = []

          @fixture_data.each do |page, data|
            all_items.concat(data["items"])
          end

          @collection_data = all_items
          @loaded = true
          true
        end

        def load_page(cursor: nil, limit: nil, timeout: DEFAULT_TIMEOUT)
          @load_count += 1

          if cursor.nil?
            # Load first page
            @current_page = 1
          else
            # Parse page number from cursor
            @current_page = cursor.split("-").last.to_i
          end

          page_key = "page#{@current_page}"

          if @fixture_data[page_key]
            page_data = @fixture_data[page_key]
            @collection_data = page_data["items"]
            @next_cursor = page_data["next_cursor"]
            @total = page_data["total"]
            @loaded = true
            return true
          end

          # Page not found
          @collection_data = []
          @next_cursor = nil
          @loaded = true
          false
        end
      end

      setup do
        @client = Minitest::Mock.new
        @client.expect :load_test_data, "request-id", [ Hash ]
        @client.expect :load_test_data, "request-id", [ Hash ]
        @client.expect :load_test_data, "request-id", [ Hash ]
        @client.expect :load_test_data, "request-id", [ Hash ]
        @fixture_data = load_fixture("paginated_catalog")
        @collection = TestCollection.new(@client, @fixture_data)
      end

      test "page returns items for the current page" do
        page_items = @collection.page
        assert_equal 3, page_items.size
        assert_equal "item1.rb", page_items.first["name"]
        assert_equal "item3.md", page_items.last["name"]

        # Verify next_cursor
        assert @collection.has_more_pages?
        assert_equal "next-page-2", @collection.next_cursor

        # Verify total
        assert_equal 10, @collection.total
      end

      test "next_page returns items for the next page" do
        @collection.page # Load first page
        next_page_items = @collection.next_page

        assert_equal 3, next_page_items.size
        assert_equal "item4.rb", next_page_items.first["name"]
        assert_equal "item6.md", next_page_items.last["name"]

        # Verify still has more pages
        assert @collection.has_more_pages?
        assert_equal "next-page-3", @collection.next_cursor
      end

      test "has_more_pages? returns false when on last page" do
        @collection.page # Load first page
        @collection.next_page # Load second page
        last_page_items = @collection.next_page # Load third page

        assert_equal 4, last_page_items.size
        assert_equal "item7.rb", last_page_items.first["name"]
        assert_equal "item10.js", last_page_items.last["name"]

        # Verify no more pages
        assert_not @collection.has_more_pages?
        assert_nil @collection.next_cursor
      end

      test "each_page iterates through all pages" do
        pages = []
        page_counts = []

        @collection.each_page do |page|
          pages << page.map { |item| item["name"] }
          page_counts << page.size
        end

        assert_equal 3, pages.size
        assert_equal [ "item1.rb", "item2.rb", "item3.md" ], pages[0]
        assert_equal [ "item4.rb", "item5.js", "item6.md" ], pages[1]
        assert_equal [ "item7.rb", "item8.css", "item9.html", "item10.js" ], pages[2]
        assert_equal [ 3, 3, 4 ], page_counts
      end

      test "all without limit loads all items at once" do
        @collection.reset
        all_items = @collection.all

        assert_equal 10, all_items.size
        assert_equal 1, @collection.load_count
      end

      test "all with limit loads items page by page" do
        @collection.reset
        all_items = @collection.all(limit: 3)

        assert_equal 10, all_items.size
        assert_equal 3, @collection.load_count # One call per page

        # Check first and last items to ensure we got all data
        assert_equal "item1.rb", all_items.first["name"]
        assert_equal "item10.js", all_items.last["name"]
      end
    end
  end
end

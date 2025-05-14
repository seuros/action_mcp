# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module ActionMCP
  module Client
    class CatalogPaginationTest < ActiveSupport::TestCase
      include FixtureHelpers

      class PaginatedCatalog < Catalog
        attr_accessor :current_page, :load_count, :fixture_data

        def initialize(client, fixture_data)
          super([], client)
          @current_page = 0
          @load_count = 0
          @load_method = :list_resources
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
          all_items = []
          @fixture_data.each do |_page, data|
            all_items.concat(data["items"])
          end
          @collection_data = all_items.map { |h| Catalog::Resource.new(h) }
          @loaded = true
          true
        end

        def load_page(cursor: nil, limit: nil, timeout: DEFAULT_TIMEOUT)
          @load_count += 1

          if cursor.nil?
            @current_page = 1
          else
            @current_page = cursor.split("-").last.to_i
          end

          page_key = "page#{@current_page}"

          if @fixture_data[page_key]
            page_data = @fixture_data[page_key]
            @collection_data = page_data["items"].map { |h| Catalog::Resource.new(h) }
            @next_cursor = page_data["next_cursor"]
            @total = page_data["total"]
            @loaded = true
            return true
          end

          @collection_data = []
          @next_cursor = nil
          @loaded = true
          false
        end
      end

      setup do
        @client = Minitest::Mock.new
        @client.expect :list_resources, "request-id", [ Hash ]
        @client.expect :list_resources, "request-id", [ Hash ]
        @client.expect :list_resources, "request-id", [ Hash ]
        @fixture_data = load_fixture("paginated_resources")
        @catalog = PaginatedCatalog.new(@client, @fixture_data)
      end

      test "page returns resources for the current page" do
        page_resources = @catalog.page
        assert_equal 3, page_resources.size
        assert_equal "resource1.txt", page_resources.first.name
        assert_equal "resource3.md", page_resources.last.name

        assert @catalog.has_more_pages?
        assert_equal "next-page-2", @catalog.next_cursor
        assert_equal 8, @catalog.total
      end

      test "next_page returns resources for the next page" do
        @catalog.page # Load first page
        next_page_resources = @catalog.next_page
        assert_equal 3, next_page_resources.size
        assert_equal "resource4.rb", next_page_resources.first.name
        assert_equal "resource6.md", next_page_resources.last.name

        assert @catalog.has_more_pages?
        assert_equal "next-page-3", @catalog.next_cursor
      end

      test "each_page iterates through all pages" do
        names = []
        @catalog.each_page { |page| names.concat(page.map(&:name)) }
        assert_equal [
          "resource1.txt", "resource2.rb", "resource3.md",
          "resource4.rb", "resource5.js", "resource6.md",
          "resource7.css", "resource8.html"
        ], names
      end

      test "has_more_pages? returns false when on last page" do
        @catalog.page # page 1
        @catalog.next_page # page 2
        @catalog.next_page # page 3
        refute @catalog.has_more_pages?
        assert_nil @catalog.next_cursor
      end

      test "all without limit loads all resources at once" do
        all_resources = @catalog.all
        assert_equal 8, all_resources.size
        assert_equal "resource1.txt", all_resources.first.name
        assert_equal "resource8.html", all_resources.last.name
      end

      test "all with limit loads resources page by page" do
        all_resources = @catalog.all(limit: 3)
        assert_equal 8, all_resources.size
        assert_equal "resource1.txt", all_resources.first.name
        assert_equal "resource8.html", all_resources.last.name
      end
    end
  end
end

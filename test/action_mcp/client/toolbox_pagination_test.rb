# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module ActionMCP
  module Client
    class ToolboxPaginationTest < ActiveSupport::TestCase
      include FixtureHelpers

      class PaginatedToolbox < Toolbox
        attr_accessor :current_page, :load_count, :fixture_data

        def initialize(client, fixture_data)
          super([], client)
          @current_page = 0
          @load_count = 0
          @load_method = :list_tools
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
          @collection_data = all_items.map { |h| Toolbox::Tool.new(h) }
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
            @collection_data = page_data["items"].map { |h| Toolbox::Tool.new(h) }
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
        @client.expect :list_tools, "request-id", [ Hash ]
        @client.expect :list_tools, "request-id", [ Hash ]
        @client.expect :list_tools, "request-id", [ Hash ]
        @fixture_data = load_fixture("paginated_tools")
        @toolbox = PaginatedToolbox.new(@client, @fixture_data)
      end

      test "page returns tools for the current page" do
        page_tools = @toolbox.page
        assert_equal 3, page_tools.size
        assert_equal "weather_forecast", page_tools.first.name
        assert_equal "format_code", page_tools.last.name

        assert @toolbox.has_more_pages?
        assert_equal "next-page-2", @toolbox.next_cursor
        assert_equal 7, @toolbox.total
      end

      test "next_page returns tools for the next page" do
        @toolbox.page # Load first page
        next_page_tools = @toolbox.next_page
        assert_equal 3, next_page_tools.size
        assert_equal "add_tool", next_page_tools.first.name
        assert_equal "numeric_array_tool", next_page_tools.last.name

        assert @toolbox.has_more_pages?
        assert_equal "next-page-3", @toolbox.next_cursor
      end

      test "each_page iterates through all pages" do
        names = []
        @toolbox.each_page { |page| names.concat(page.map(&:name)) }
        assert_equal [
          "weather_forecast", "calculate_sum", "format_code",
          "add_tool", "checksum_checker", "numeric_array_tool",
          "progress2025_demo_tool"
        ], names
      end

      test "has_more_pages? returns false when on last page" do
        @toolbox.page # page 1
        @toolbox.next_page # page 2
        @toolbox.next_page # page 3
        refute @toolbox.has_more_pages?
        assert_nil @toolbox.next_cursor
      end

      test "all without limit loads all tools at once" do
        all_tools = @toolbox.all
        assert_equal 7, all_tools.size
        assert_equal "weather_forecast", all_tools.first.name
        assert_equal "progress2025_demo_tool", all_tools.last.name
      end

      test "all with limit loads tools page by page" do
        all_tools = @toolbox.all(limit: 3)
        assert_equal 7, all_tools.size
        assert_equal "weather_forecast", all_tools.first.name
        assert_equal "progress2025_demo_tool", all_tools.last.name
      end
    end
  end
end

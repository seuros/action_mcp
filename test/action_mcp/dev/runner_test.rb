# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Dev
    class RunnerTest < ActiveSupport::TestCase
      setup do
        @root = Dir.mktmpdir("action_mcp_dev")
        @out = StringIO.new
      end

      teardown { FileUtils.remove_entry(@root) }

      def runner(argv = [])
        Runner.new(root: @root, argv: argv, out: @out)
      end

      def with_views
        FileUtils.mkdir_p(File.join(@root, "app/mcp/views"))
      end

      def labels(runner) = runner.plan.map(&:label)

      test "plan is just the server when no views tier is present" do
        assert_equal %w[server], labels(runner)
      end

      test "plan adds the view watcher when app/mcp/views exists" do
        with_views
        assert_equal %w[server views], labels(runner)
      end

      test "--no-views suppresses the watcher even when views exist" do
        with_views
        assert_equal %w[server], labels(runner(%w[--no-views]))
      end

      test "--tunnel adds a cloudflared process" do
        with_views
        r = runner(%w[--tunnel])
        assert_equal %w[server views tunnel], labels(r)
        tunnel = r.plan.find { |s| s.label == "tunnel" }
        assert_equal %w[cloudflared tunnel --url http://localhost:62770], tunnel.command
      end

      test "views watcher runs the plugin bin in watch mode against the root" do
        with_views
        views = runner.plan.find { |s| s.label == "views" }
        assert_includes views.command, "action-mcp-build-views"
        assert_includes views.command, "--watch"
        assert_equal @root, views.command.last
      end

      test "node runner follows the project lockfile" do
        with_views
        assert_equal "npx", runner.plan.find { |s| s.label == "views" }.command.first

        File.write(File.join(@root, "bun.lock"), "")
        assert_equal "bunx", runner.plan.find { |s| s.label == "views" }.command.first

        File.delete(File.join(@root, "bun.lock"))
        File.write(File.join(@root, "pnpm-lock.yaml"), "")
        assert_equal %w[pnpm exec], runner.plan.find { |s| s.label == "views" }.command.first(2)
      end

      test "port is configurable via bare arg, -p, and --port=" do
        assert_includes port_command(runner(%w[3001])), "3001"
        assert_includes port_command(runner(%w[-p 4001])), "4001"
        assert_includes port_command(runner(%w[--port=5001])), "5001"
      end

      test "server binds to loopback by default" do
        assert_includes port_command(runner), "http://127.0.0.1:62770"
      end

      test "Puma fallback binds to loopback by default" do
        instance = runner
        instance.define_singleton_method(:falcon_available?) { false }

        command = instance.plan.find { |spec| spec.label == "server" }.command
        assert_includes command.each_cons(2).to_a, [ "-b", "127.0.0.1" ]
      end

      test "unknown option raises with usage" do
        error = assert_raises(ArgumentError) { runner(%w[--bogus]) }
        assert_match(/unknown option: --bogus/, error.message)
      end

      test "--help prints usage and does not spawn" do
        assert_equal 0, runner(%w[--help]).run
        assert_match(/Usage: bin\/mcp dev/, @out.string)
      end

      private

      # The server command embeds the port whether Falcon (--bind ...:PORT) or
      # Puma (-p PORT) is selected; assert on the joined command.
      def port_command(runner)
        runner.plan.find { |s| s.label == "server" }.command.join(" ")
      end
    end
  end
end

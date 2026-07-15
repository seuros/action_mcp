# frozen_string_literal: true

module ActionMCP
  module Dev
    # A single command that boots the ActionMCP dev loop: the standalone MCP
    # server plus, when a compiled-views tier is present, the vite view builder
    # in watch mode, plus an optional public tunnel.
    #
    # Note on the reload model: MCP Apps views are delivered to hosts as
    # inlined resource text inside a sandboxed iframe, so there is no websocket
    # channel for classic in-browser HMR. The dev loop is watch-and-rebuild:
    # editing a view triggers a vite rebuild of its bundle + manifest, and the
    # next tool invocation in the MCP client renders the fresh view.
    #
    # Usage from the generated binstub:
    #   ActionMCP::Dev::Runner.new(root: Dir.pwd, argv: ARGV).run
    class Runner
      DEFAULT_PORT = 62_770
      VIEWS_SUBDIR = "app/mcp/views"
      BUILD_BIN = "action-mcp-build-views"

      # A child process to supervise.
      Spec = Struct.new(:label, :command, :env, keyword_init: true)

      attr_reader :root, :options

      def initialize(root:, argv: [], env: ENV, out: $stdout)
        @root = File.expand_path(root)
        @env = env
        @out = out
        @options = parse(argv)
        @pids = {}
      end

      # The set of child processes this invocation would start. Pure — no
      # spawning — so the wiring is unit-testable.
      #
      # @return [Array<Spec>]
      def plan
        specs = [ server_spec ]
        specs << views_spec if run_views?
        specs << tunnel_spec if @options[:tunnel]
        specs
      end

      # Whether the vite view-builder should run: opt-in tier is present and the
      # user did not disable it.
      def run_views?
        @options[:views] && File.directory?(File.join(@root, VIEWS_SUBDIR))
      end

      def run
        if @options[:help]
          @out.puts usage
          return 0
        end

        specs = plan
        print_banner(specs)

        specs.each { |spec| spawn(spec) }
        install_signal_traps
        supervise
      end

      private

      def parse(argv)
        opts = { port: DEFAULT_PORT, views: true, tunnel: false, help: false }
        args = argv.dup

        until args.empty?
          arg = args.shift
          case arg
          when "-h", "--help"      then opts[:help] = true
          when "--no-views"        then opts[:views] = false
          when "--tunnel"          then opts[:tunnel] = true
          when "-p", "--port"      then opts[:port] = Integer(args.shift)
          else
            if (m = arg.match(/\A--port=(.+)\z/))
              opts[:port] = Integer(m[1])
            elsif arg.match?(/\A\d+\z/)
              opts[:port] = Integer(arg) # bare port, matching `bin/mcp 3001`
            else
              raise ArgumentError, "unknown option: #{arg}\n\n#{usage}"
            end
          end
        end

        opts
      end

      def server_spec
        rackup = File.join(@root, "mcp", "config.ru")
        command =
          if falcon_available?
            [ "bundle", "exec", "falcon", "serve",
              "--bind", "http://127.0.0.1:#{@options[:port]}", "--config", rackup ]
          else
            [ "bundle", "exec", "rails", "server", "-c", rackup,
              "-b", "127.0.0.1", "-p", @options[:port].to_s ]
          end
        Spec.new(label: "server", command: command, env: {})
      end

      def views_spec
        command = [ *node_runner, BUILD_BIN, "--watch", "--root", @root ]
        Spec.new(label: "views", command: command, env: {})
      end

      def tunnel_spec
        command = [ "cloudflared", "tunnel", "--url", "http://localhost:#{@options[:port]}" ]
        Spec.new(label: "tunnel", command: command, env: {})
      end

      # Prefer the package runner matching the lockfile in the project so the
      # locally-installed @action-mcp/vite-plugin bin resolves.
      def node_runner
        if File.exist?(File.join(@root, "bun.lock")) || File.exist?(File.join(@root, "bun.lockb"))
          [ "bunx" ]
        elsif File.exist?(File.join(@root, "pnpm-lock.yaml"))
          [ "pnpm", "exec" ]
        else
          [ "npx" ]
        end
      end

      def falcon_available?
        Gem::Specification.find_by_name("falcon")
        true
      rescue Gem::MissingSpecError
        false
      end

      def spawn(spec)
        @out.puts "  ▸ #{spec.label}: #{spec.command.join(' ')}"
        pid = Process.spawn(spec.env, *spec.command, chdir: @root)
        @pids[pid] = spec.label
      end

      def install_signal_traps
        %w[INT TERM].each do |sig|
          Signal.trap(sig) { shutdown(sig) }
        end
      end

      # Wait for any child to exit; when one dies, tear the rest down so the dev
      # loop never limps along half-up.
      def supervise
        pid = Process.wait
        label = @pids.delete(pid)
        status = $?
        @out.puts "\n[action-mcp] #{label} exited (#{status.exitstatus || status.termsig}); stopping dev loop."
        shutdown("TERM")
        status.exitstatus || 1
      rescue Interrupt
        shutdown("TERM")
        130
      end

      def shutdown(sig)
        @pids.each_key do |pid|
          Process.kill(sig, pid)
        rescue Errno::ESRCH
          # already gone
        end
        @pids.each_key do |pid|
          Process.wait(pid)
        rescue Errno::ECHILD
          # already reaped
        end
        @pids.clear
        exit(0) if sig == "INT"
      end

      def print_banner(specs)
        @out.puts "ActionMCP dev loop"
        @out.puts "  server:    http://localhost:#{@options[:port]}"
        @out.puts "  views:     #{run_views? ? 'watching app/mcp/views' : 'disabled'}"
        @out.puts "  tunnel:    #{@options[:tunnel] ? 'cloudflared' : 'off (pass --tunnel)'}"
        @out.puts "  inspect:   npx @modelcontextprotocol/inspector " \
                  "--url http://localhost:#{@options[:port]}"
        @out.puts "  (#{specs.size} process#{'es' if specs.size != 1})"
        @out.puts
      end

      def usage
        <<~USAGE
          Usage: bin/mcp dev [options]

          Boots the MCP server and, when app/mcp/views exists, the vite view
          builder in watch mode.

          Options:
            -p, --port PORT   Server port (default: #{DEFAULT_PORT})
            --no-views        Do not start the view builder
            --tunnel          Expose the server publicly via cloudflared
            -h, --help        Show this help
        USAGE
      end
    end
  end
end

# frozen_string_literal: true

require "open3"

module ActionMCP
  module Client
    # MCP client using Standard I/O (STDIO) transport
    class StdioClient < Base
      def initialize(command, logger: ActionMCP.logger, **_options)
        super(logger: logger)
        @type = :stdio
        @command = command
        @threads_started = false
        @received_server_message = false
        @capabilities_sent = false
      end

      protected

      def start_transport
        setup_stdio_process
        start_output_threads

        # Just log that connection is established but don't send capabilities yet
        if @threads_started && @wait_thr.alive?
          log_info("STDIO connection established")
          true
        else
          log_error("Failed to start STDIO threads or process is not alive")
          false
        end
      end

      def stop_transport
        cleanup_resources
      end

      def send_message(json)
        log_debug("\e[34m--> #{json}\e[0m")
        @stdin.puts("#{json}\n\n")
      end

      def ready?
        @received_server_message
      end

      private

      def setup_stdio_process
        @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(@command)
      end

      def start_output_threads
        @stdout_thread = Thread.new do
          @stdout.each_line do |line|
            line = line.chomp
            # Mark ready and send capabilities when we get any stdout
            mark_ready_and_send_capabilities

            # Continue with normal message handling
            handle_raw_message(line)
          end
        end

        @stderr_thread = Thread.new do
          @stderr.each_line do |line|
            line = line.chomp
            log_info(line)

            # Check stderr for server messages
            mark_ready_and_send_capabilities if line.include?("MCP Server") || line.include?("running on stdio")
          end
        end

        @threads_started = true
      end

      # Mark the client as ready and send initial capabilities if not already sent
      def mark_ready_and_send_capabilities
        return if @received_server_message

        @received_server_message = true
        log_info("Received first server message")

        # Send initial capabilities if not already sent
        return if @capabilities_sent

        log_info("Server is ready, sending initial capabilities...")
        send_initial_capabilities
        @capabilities_sent = true
      end

      def cleanup_resources
        @stdin.close
        wait_for_server_exit
        cleanup_threads
      end

      def wait_for_server_exit
        @wait_thr.join(0.5)
        kill_server if @wait_thr.alive?
      end

      def kill_server
        Process.kill("TERM", @wait_thr.pid)
      rescue StandardError => e
        log_error("Failed to kill server process: #{e}")
      end

      def cleanup_threads
        @stdout_thread&.kill
        @stderr_thread&.kill
      end
    end
  end
end

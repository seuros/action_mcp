# frozen_string_literal: true

require "open3"
module ActionMCP
  module Transport
    class Stdio < TransportBase
      def initialize(command, **options)
        super(**options)
        @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(command)
      end

      def start
        start_output_threads
      end

      def send_message(json)
        log_debug("--> #{json}")
        @stdin.puts(json)
      end

      def stop
        cleanup_resources
      end

      private

      def start_output_threads
        @stdout_thread = Thread.new do
          @stdout.each_line { |line| handle_raw_message(line.chomp) }
        end

        @stderr_thread = Thread.new do
          @stderr.each_line { |line| log_info(line.chomp) }
        end
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

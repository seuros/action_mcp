# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class ServerTest < ActiveSupport::TestCase
      def setup
        @temp_files = []
      end

      def teardown
        @temp_files.each do |file|
          file.close
          begin
            file.unlink
          rescue StandardError
            nil
          end
        end
      end

      def test_server_returns_server_instance
        server = ActionMCP::Server.server
        assert_instance_of ActionMCP::Server::ServerBase, server
      end

      def test_server_is_singleton
        server1 = ActionMCP::Server.server
        server2 = ActionMCP::Server.server
        assert_same server1, server2
      end

      def test_pubsub_creates_default_adapter_without_config
        server = ServerBase.new("/non/existent/path.yml")
        adapter = server.pubsub

        assert_instance_of SimplePubSub, adapter
      end

      def test_pubsub_creates_simple_adapter_from_config
        config_file = create_temp_config_file(
          "test" => { "adapter" => "simple" }
        )
        @temp_files << config_file

        server = ServerBase.new(config_file.path)
        adapter = server.pubsub

        assert_instance_of SimplePubSub, adapter
      end

      def test_pubsub_creates_solid_cable_adapter_from_config
        config_file = create_temp_config_file(
          "test" => {
            "adapter" => "solid_cable",
            "polling_interval" => 0.1
          }
        )
        @temp_files << config_file

        server = ServerBase.new(config_file.path)
        adapter = server.pubsub

        assert_instance_of SolidCableAdapter, adapter
      end

      def test_configure_updates_configuration
        # Start with simple adapter
        config_file1 = create_temp_config_file(
          "test" => { "adapter" => "simple" }
        )
        @temp_files << config_file1

        server = ServerBase.new(config_file1.path)
        adapter1 = server.pubsub
        assert_instance_of SimplePubSub, adapter1

        # Now update to solid_cable adapter if available
        return unless defined?(SolidCable)

        config_file2 = create_temp_config_file(
          "test" => { "adapter" => "solid_cable" }
        )
        @temp_files << config_file2

        server.configure(config_file2.path)
        adapter2 = server.pubsub

        assert_instance_of SolidCableAdapter, adapter2
        refute_same adapter1, adapter2
      end

      def test_fallback_to_simple_for_missing_adapter
        config_file = create_temp_config_file(
          "test" => { "adapter" => "invalid_adapter" }
        )
        @temp_files << config_file

        server = ServerBase.new(config_file.path)
        adapter = server.pubsub

        assert_instance_of SimplePubSub, adapter
      end
    end
  end
end

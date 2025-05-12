# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class ConfigurationTest < ActiveSupport::TestCase
      def setup
        @temp_files = []
      end

      def teardown
        @temp_files.each do |file|
          file.close
          file.unlink rescue nil
        end
      end

      def test_load_empty_config
        config = Configuration.new("/non/existent/path.yml")
        assert_equal({}, config.config)
      end

      def test_load_from_file
        config_file = create_temp_config_file(
          "development" => { "adapter" => "simple" },
          "test" => { "adapter" => "test" },
          "production" => { "adapter" => "solid_cable", "polling_interval" => 0.5 }
        )
        @temp_files << config_file

        config = Configuration.new(config_file.path)

        assert_equal "simple", config.for_env("development")["adapter"]
        assert_equal "test", config.for_env("test")["adapter"]
        assert_equal "solid_cable", config.for_env("production")["adapter"]
        assert_equal 0.5, config.for_env("production")["polling_interval"]
      end

      def test_for_env_returns_correct_environment
        config_file = create_temp_config_file(
          "development" => { "adapter" => "simple" },
          "test" => { "adapter" => "test" }
        )
        @temp_files << config_file

        config = Configuration.new(config_file.path)

        assert_equal({ "adapter" => "simple" }, config.for_env("development"))
        assert_equal({ "adapter" => "test" }, config.for_env("test"))
      end

      def test_for_env_defaults_to_development
        config_file = create_temp_config_file(
          "development" => { "adapter" => "simple" }
        )
        @temp_files << config_file

        config = Configuration.new(config_file.path)

        assert_equal({ "adapter" => "simple" }, config.for_env("nonexistent"))
      end

      def test_for_env_returns_empty_hash_if_no_environments
        config_file = create_temp_config_file({})
        @temp_files << config_file

        config = Configuration.new(config_file.path)

        assert_equal({}, config.for_env("development"))
      end

      def test_adapter_name_returns_adapter
        config_file = create_temp_config_file(
          "development" => { "adapter" => "simple" },
          "test" => { "adapter" => "test" }
        )
        @temp_files << config_file

        config = Configuration.new(config_file.path)

        assert_equal "simple", config.adapter_name("development")
        assert_equal "test", config.adapter_name("test")
      end

      def test_adapter_options_returns_options_without_adapter
        config_file = create_temp_config_file(
          "development" => {
            "adapter" => "solid_cable",
            "polling_interval" => 0.5,
            "connects_to" => "cable"
          }
        )
        @temp_files << config_file

        config = Configuration.new(config_file.path)

        expected = { "polling_interval" => 0.5, "connects_to" => "cable" }
        assert_equal expected, config.adapter_options("development")
      end

      def test_adapter_options_returns_empty_hash_if_no_options
        config_file = create_temp_config_file(
          "development" => { "adapter" => "simple" }
        )
        @temp_files << config_file

        config = Configuration.new(config_file.path)

        assert_equal({}, config.adapter_options("development"))
      end
    end
  end
end

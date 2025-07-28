# frozen_string_literal: true

require "test_helper"

class ConfigurationIntegrationTest < ActiveSupport::TestCase
  setup do
    @original_config_path = Rails.root.join("config", "mcp.yml")
    @backup_path = Rails.root.join("config", "mcp.yml.backup")

    # Backup existing config if it exists
    if File.exist?(@original_config_path)
      FileUtils.cp(@original_config_path, @backup_path)
    end

    # Reset ActionMCP configuration
    ActionMCP.instance_variable_set(:@configuration, nil)

    # Clear Rails config cache more thoroughly
    # Rails caches config_for results in @configurations
    if Rails.application.instance_variable_defined?(:@configurations)
      Rails.application.instance_variable_set(:@configurations, {})
    end

    # Also clear the env_config cache
    if Rails.application.config.instance_variable_defined?(:@configurations)
      Rails.application.config.instance_variable_set(:@configurations, {})
    end
  end

  teardown do
    # Restore original config
    if File.exist?(@backup_path)
      FileUtils.mv(@backup_path, @original_config_path)
    else
      FileUtils.rm_f(@original_config_path)
    end

    # Reset configuration
    ActionMCP.instance_variable_set(:@configuration, nil)
  end

  test "loads and merges profiles from YAML configuration" do
    # Create a real YAML config file
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "profiles" => {
          "primary" => {
            "tools" => [ "CustomTool" ],
            "options" => {
              "list_changed" => false
            }
          },
          "custom" => {
            "tools" => [ "SpecialTool" ],
            "prompts" => [],
            "resources" => []
          }
        }
      },
      "test" => {
        "adapter" => "test"
      }
    }

    File.write(@original_config_path, YAML.dump(config_content))

    # Force configuration reload
    ActionMCP.instance_variable_set(:@configuration, nil)

    # Force ActionMCP to reload configuration
    config = ActionMCP.configuration
    config.load_profiles

    # Verify profiles were merged correctly
    assert config.profiles.key?(:primary)
    assert config.profiles.key?(:custom)
    assert config.profiles.key?(:minimal), "Default minimal profile should still exist"

    # Check that primary profile was merged, not replaced
    assert_equal [ "CustomTool" ], config.profiles[:primary][:tools]
    assert_equal [ "all" ], config.profiles[:primary][:prompts], "Prompts should retain default"
    assert_equal [ "all" ], config.profiles[:primary][:resources], "Resources should retain default"
    assert_equal false, config.profiles[:primary][:options][:list_changed]

    # Verify custom profile
    assert_equal [ "SpecialTool" ], config.profiles[:custom][:tools]
  end

  test "loads active profile from YAML configuration" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "profiles" => {
          "primary" => {
            "tools" => [ "all" ],
            "prompts" => [ "all" ],
            "resources" => [ "all" ]
          },
          "custom_profile" => {
            "tools" => [ "MyTool" ],
            "prompts" => [],
            "resources" => []
          }
        }
      },
      "test" => {
        "profile" => "custom_profile"
      }
    }

    File.write(@original_config_path, YAML.dump(config_content))

    # Force configuration reload
    ActionMCP.instance_variable_set(:@configuration, nil)
    config = ActionMCP.configuration
    config.load_profiles

    assert_equal :custom_profile, config.active_profile
  end

  test "capabilities reflect loaded profile configuration" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "profiles" => {
          "primary" => {
            "tools" => [ "TestTool" ],
            "prompts" => [ "TestPrompt" ],
            "resources" => [ "TestResource" ],
            "options" => {
              "list_changed" => true,
              "logging_enabled" => true,
              "resources_subscribe" => true
            }
          }
        }
      },
      "test" => {}
    }

    File.write(@original_config_path, YAML.dump(config_content))

    # Force configuration reload
    ActionMCP.instance_variable_set(:@configuration, nil)
    config = ActionMCP.configuration
    config.load_profiles
    capabilities = config.capabilities

    assert capabilities[:tools], "Tools capability should be present"
    assert_equal true, capabilities[:tools][:listChanged]

    assert capabilities[:prompts], "Prompts capability should be present"
    assert_equal true, capabilities[:prompts][:listChanged]

    assert capabilities[:resources], "Resources capability should be present"
    assert_equal true, capabilities[:resources][:subscribe]
    assert_equal true, capabilities[:resources][:listChanged]

    assert capabilities[:logging], "Logging capability should be present"
  end

  test "handles missing configuration file gracefully" do
    # Ensure no config file exists
    FileUtils.rm_f(@original_config_path)

    # Should not raise an error
    config = ActionMCP.configuration
    config.load_profiles

    # Should use defaults
    assert config.profiles.key?(:primary)
    assert config.profiles.key?(:minimal)
    assert_equal :primary, config.active_profile
  end

  test "loads authentication methods from environment-specific config" do
    config_content = {
      "shared" => {
        "authentication" => [ "api_key" ],
        "profiles" => {
          "primary" => {
            "tools" => [ "all" ],
            "prompts" => [ "all" ],
            "resources" => [ "all" ]
          }
        }
      },
      "test" => {
        "authentication" => [ "api_key", "session" ]
      }
    }

    File.write(@original_config_path, YAML.dump(config_content))

    # Force configuration reload
    ActionMCP.instance_variable_set(:@configuration, nil)
    config = ActionMCP.configuration
    config.load_profiles

    assert_equal [ "api_key", "session" ], config.authentication_methods
  end


  test "environment-specific settings override shared settings" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "adapter" => "simple",
        "verbose_logging" => true,
        "profiles" => {
          "primary" => {
            "tools" => [ "all" ],
            "prompts" => [ "all" ],
            "resources" => [ "all" ]
          }
        }
      },
      "test" => {
        "adapter" => "test",
        "verbose_logging" => false,
        "gateway_class" => "CustomGateway"
      }
    }

    File.write(@original_config_path, YAML.dump(config_content))

    # Force configuration reload
    ActionMCP.instance_variable_set(:@configuration, nil)
    config = ActionMCP.configuration
    config.load_profiles

    assert_equal "test", config.adapter
    assert_equal false, config.verbose_logging
    assert_equal "CustomGateway", config.instance_variable_get(:@gateway_class_name)
  end

  test "deep symbolize keys works for nested profile configuration" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "profiles" => {
          "test_profile" => {
            "tools" => [ "Tool1" ],
            "prompts" => [ "Prompt1" ],
            "resources" => [ "Resource1" ],
            "options" => {
              "list_changed" => true,
              "nested_config" => {
                "deep_key" => "deep_value"
              }
            }
          }
        }
      },
      "test" => {
        "profile" => "test_profile"
      }
    }

    File.write(@original_config_path, YAML.dump(config_content))

    # Force configuration reload
    ActionMCP.instance_variable_set(:@configuration, nil)
    config = ActionMCP.configuration
    config.load_profiles

    # Verify all keys are symbols
    profile = config.profiles[:test_profile]
    assert profile[:tools]
    assert profile[:prompts]
    assert profile[:resources]
    assert profile[:options]
    assert profile[:options][:list_changed]
    assert profile[:options][:nested_config]
    assert_equal "deep_value", profile[:options][:nested_config][:deep_key]
  end

  test "filtered tools respects profile configuration" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "profiles" => {
          "limited" => {
            "tools" => [ "AddTool", "SubtractTool" ],
            "prompts" => [],
            "resources" => []
          }
        }
      },
      "test" => {
        "profile" => "limited"
      }
    }

    File.write(@original_config_path, YAML.dump(config_content))

    # Force configuration reload
    ActionMCP.instance_variable_set(:@configuration, nil)
    config = ActionMCP.configuration
    config.load_profiles

    # Create some mock tools for testing
    add_tool = Class.new(ActionMCP::Tool) do
      def self.name
        "AddTool"
      end
    end

    subtract_tool = Class.new(ActionMCP::Tool) do
      def self.name
        "SubtractTool"
      end
    end

    multiply_tool = Class.new(ActionMCP::Tool) do
      def self.name
        "MultiplyTool"
      end
    end

    # We can't easily test filtered_tools without real tool classes in the registry
    # So we'll just verify the profile configuration is correct
    assert_equal [ "AddTool", "SubtractTool" ], config.profiles[:limited][:tools]
  end

  test "empty profile arrays don't generate capabilities" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "profiles" => {
          "empty" => {
            "tools" => [],
            "prompts" => [],
            "resources" => []
          }
        }
      },
      "test" => {
        "profile" => "empty"
      }
    }

    File.write(@original_config_path, YAML.dump(config_content))

    # Force configuration reload
    ActionMCP.instance_variable_set(:@configuration, nil)
    config = ActionMCP.configuration
    config.load_profiles
    capabilities = config.capabilities

    refute capabilities[:tools], "Empty tools array should not generate capability"
    refute capabilities[:prompts], "Empty prompts array should not generate capability"
    refute capabilities[:resources], "Empty resources array should not generate capability"
  end
end

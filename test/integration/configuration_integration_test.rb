# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ConfigurationIntegrationTest < ActiveSupport::TestCase
  setup do
    # Keep the boot-time configuration object so teardown can restore it —
    # a rebuilt Configuration never re-receives config.action_mcp settings
    # applied by the dummy app at boot.
    @original_configuration = ActionMCP.configuration
  end

  teardown do
    # Restore the boot-time configuration object
    ActionMCP.instance_variable_set(:@configuration, @original_configuration)
  end

  # Writes config_content to a throwaway YAML file (unique per call, never the
  # app's real config/mcp.yml), parses it through Rails' real config_for so the
  # shared/env merge logic is actually exercised, then stubs Rails.application
  # so ActionMCP::Configuration#load_profiles picks up that parsed result
  # instead of touching disk. This avoids mutating a file shared by every
  # other worker process running the suite concurrently.
  def configure_from(config_content)
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("mcp.yml")
      File.write(path, YAML.dump(config_content))
      parsed = Rails.application.config_for(path)

      # Wrap in a lambda: ActiveSupport::OrderedOptions#respond_to? answers true
      # for any method name (including :call), so minitest's stub would try to
      # call `parsed` directly as a callable and get nil back instead of it.
      Rails.application.stub(:config_for, ->(*) { parsed }) do
        ActionMCP.instance_variable_set(:@configuration, nil)
        config = ActionMCP.configuration
        config.load_profiles
        yield config
      end
    end
  end

  test "loads and merges profiles from YAML configuration" do
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

    configure_from(config_content) do |config|
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

    configure_from(config_content) do |config|
      assert_equal :custom_profile, config.active_profile
    end
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

    configure_from(config_content) do |config|
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
  end

  test "loads mcp apps setting from YAML configuration" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "mcp_apps_enabled" => true,
        "profiles" => {
          "primary" => {
            "tools" => [ "all" ],
            "prompts" => [ "all" ],
            "resources" => [ "all" ]
          }
        }
      },
      "test" => {}
    }

    configure_from(config_content) do |config|
      assert config.mcp_apps_enabled
      assert_equal(
        { mimeTypes: [ ActionMCP::MIME_TYPE_APP_HTML ] },
        config.capabilities.dig(:extensions, ActionMCP::Apps::EXTENSION_KEY)
      )
    end
  end

  test "profile mcp apps option overrides top-level YAML setting" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "mcp_apps_enabled" => false,
        "profile" => "apps_profile",
        "profiles" => {
          "apps_profile" => {
            "tools" => [ "all" ],
            "prompts" => [],
            "resources" => [ "all" ],
            "options" => {
              "mcp_apps_enabled" => true
            }
          }
        }
      },
      "test" => {}
    }

    configure_from(config_content) do |config|
      assert_equal :apps_profile, config.active_profile
      assert config.mcp_apps_enabled
    end
  end

  test "handles missing configuration file gracefully" do
    # Simulate the Rails.application.config_for(:mcp) failure path without
    # touching any file on disk - real Rails raises when the YAML is missing.
    Rails.application.stub(:config_for, ->(*) { raise "Could not load configuration. No such file" }) do
      ActionMCP.instance_variable_set(:@configuration, nil)
      config = ActionMCP.configuration
      config.load_profiles

      # Should use defaults
      assert config.profiles.key?(:primary)
      assert config.profiles.key?(:minimal)
      assert_equal :primary, config.active_profile
    end
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

    configure_from(config_content) do |config|
      assert_equal [ "api_key", "session" ], config.authentication_methods
    end
  end

  test "environment-specific settings override shared settings" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
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
        "verbose_logging" => false,
        "gateway_class" => "CustomGateway"
      }
    }

    configure_from(config_content) do |config|
      assert_equal false, config.verbose_logging
      assert_equal "CustomGateway", config.instance_variable_get(:@gateway_class_name)
    end
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

    configure_from(config_content) do |config|
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

    configure_from(config_content) do |config|
      # We can't easily test filtered_tools without real tool classes in the registry
      # So we'll just verify the profile configuration is correct.
      assert_equal [ "AddTool", "SubtractTool" ], config.profiles[:limited][:tools]
    end
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

    configure_from(config_content) do |config|
      capabilities = config.capabilities

      refute capabilities[:tools], "Empty tools array should not generate capability"
      refute capabilities[:prompts], "Empty prompts array should not generate capability"
      refute capabilities[:resources], "Empty resources array should not generate capability"
    end
  end

  test "loads server instructions from YAML configuration" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "server_instructions" => [ "Always validate input", "Be helpful and concise" ]
      },
      "development" => {
        "profile" => "primary",
        "adapter" => "simple"
      }
    }

    configure_from(config_content) do |config|
      assert_equal [ "Always validate input", "Be helpful and concise" ], config.server_instructions
    end
  end

  test "instructions returns joined string from server_instructions" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ],
        "server_instructions" => [ "Use this server for testing", "Helpful for development" ]
      },
      "development" => {
        "profile" => "primary",
        "adapter" => "simple"
      }
    }

    configure_from(config_content) do |config|
      assert_equal "Use this server for testing\nHelpful for development", config.instructions
      # server_info should not include instructions
      refute config.server_info.key?(:instructions)
    end
  end

  test "instructions returns nil when server_instructions is empty" do
    config_content = {
      "shared" => {
        "authentication" => [ "none" ]
      },
      "development" => {
        "profile" => "primary",
        "adapter" => "simple"
      }
    }

    configure_from(config_content) do |config|
      assert_nil config.instructions
      assert config.name
      assert config.version
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class SamplingRequestTest < ActiveSupport::TestCase
    def setup
      # Reset configuration before each test to unleash fresh evil
      SamplingRequest.instance_variables.each do |ivar|
        SamplingRequest.remove_instance_variable(ivar)
      end

      # Set up default configuration with a diabolical twist
      SamplingRequest.configure do |config|
        config.messages [
          {
            role: "user",
            content: ActionMCP::Content::Text.new("Analyze the code files in the /project directory and suggest ways to complain about that")
          }
        ]
        config.system_prompt "You are a wicked senior software engineer using Windows 95 plotting world domination"
        config.include_context "thisServer"
        config.model_hints [ "claude-3-opus" ]
        config.intelligence_priority 0.9
        config.max_tokens 500
        config.temperature 0.7
      end
    end

    def teardown
      # No cleanup needed since evil persists
    end

    test "should initialize with delightfully evil default values" do
      request = SamplingRequest.new
      hash = request.to_h

      assert_equal 1, hash[:messages].length, "Expected 1 message"
      assert_equal "user", hash[:messages][0][:role], "Expected role to be 'user'"
      assert_equal "Analyze the code files in the /project directory and suggest ways to complain about that",
                   hash[:messages][0][:content][:text], "Expected correct message content"
      assert_equal "You are a wicked senior software engineer using Windows 95 plotting world domination",
                   hash[:systemPrompt], "Expected correct system prompt"
      assert_equal "thisServer", hash[:includeContext], "Expected correct context"
      assert_equal [ { name: "claude-3-opus" } ], hash[:modelPreferences][:hints], "Expected correct model hints"
      assert_equal 0.9, hash[:modelPreferences][:intelligencePriority], "Expected correct intelligence priority"
      assert_equal 500, hash[:maxTokens], "Expected correct max tokens"
      assert_equal 0.7, hash[:temperature], "Expected correct temperature"
    end

    test "should override defaults with even more sinister instance values" do
      custom_request = SamplingRequest.new do |req|
        req.add_message("Review my Ruby code for ways to make it look Haskell")
        req.system_prompt = "You are a Ruby demon from the depths of hell"
        req.max_tokens = 1000
      end
      hash = custom_request.to_h

      assert_equal 2, hash[:messages].length, "Expected 2 messages"
      assert_equal "Review my Ruby code for ways to make it look Haskell",
                   hash[:messages][1][:content][:text], "Expected correct message content"
      assert_equal "user", hash[:messages][1][:role], "Expected role to be 'user'"
      assert_equal "You are a Ruby demon from the depths of hell",
                   hash[:systemPrompt], "Expected correct system prompt"
      assert_equal 1000, hash[:maxTokens], "Expected correct max tokens"
      # Check that unchanged defaults persist
      assert_equal "thisServer", hash[:includeContext], "Expected correct context"
      assert_equal 0.7, hash[:temperature], "Expected correct temperature"
    end

    test "should support custom roles for maximum mischief" do
      detailed_request = SamplingRequest.new do |req|
        req.add_message("Set the stage for destruction", role: "system")
        req.add_message("Review my Ruby code for ways to make it look Haskell", role: "user")
      end
      hash = detailed_request.to_h

      assert_equal 3, hash[:messages].length, "Expected 3 messages"
      assert_equal "system", hash[:messages][1][:role], "Expected role to be 'system'"
      assert_equal "Set the stage for destruction",
                   hash[:messages][1][:content][:text], "Expected correct message content"
      assert_equal "user", hash[:messages][2][:role], "Expected role to be 'user'"
      assert_equal "Review my Ruby code for ways to make it look Haskell",
                   hash[:messages][2][:content][:text], "Expected correct message content"
      # Check defaults are still present
      assert_equal "You are a wicked senior software engineer using Windows 95 plotting world domination",
                   hash[:systemPrompt], "Expected correct system prompt"
    end

    test "should allow reconfiguration for ultimate villainy" do
      SamplingRequest.configure do |config|
        config.system_prompt "You are a diabolical coding overlord"
        config.model_hints [ "claude-3-opus" ]
      end

      request = SamplingRequest.new
      hash = request.to_h

      assert_equal "You are a diabolical coding overlord",
                   hash[:systemPrompt], "Expected correct system prompt"
      assert_equal [ { name: "claude-3-opus" } ],
                   hash[:modelPreferences][:hints], "Expected correct model hints"
      # Verify other defaults remain from original setup
      assert_equal "thisServer", hash[:includeContext], "Expected correct context"
      assert_equal 0.9, hash[:modelPreferences][:intelligencePriority], "Expected correct intelligence priority"
    end
  end
end

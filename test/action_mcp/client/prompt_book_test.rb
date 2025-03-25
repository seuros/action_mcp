# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Client
    class PromptBookTest < ActiveSupport::TestCase
      setup do
        @prompt_data = [
          {
            "name" => "summarize_text",
            "description" => "Summarize a piece of text using a chosen method",
            "arguments" => [
              { "name" => "text", "description" => "Text to summarize", "required" => true },
              { "name" => "style", "description" => "Summarization style", "required" => false }
            ]
          },
          {
            "name" => "greeting",
            "description" => "Generates a personalized greeting message",
            "arguments" => [
              { "name" => "name", "description" => "The name to greet", "required" => true },
              { "name" => "style", "description" => "Style of greeting", "required" => false }
            ]
          }
        ]
        @collection = PromptBook.new(@prompt_data, nil)
      end

      test "initializes with prompt data" do
        assert_equal 2, @collection.size
      end

      test "returns all prompts" do
        prompts = @collection.all
        assert_equal 2, prompts.size
        assert_instance_of PromptBook::Prompt, prompts.first
      end

      test "finds a prompt by name" do
        prompt = @collection.find("greeting")
        assert_equal "greeting", prompt.name
        assert_equal "Generates a personalized greeting message", prompt.description
      end

      test "returns nil when finding a nonexistent prompt" do
        assert_nil @collection.find("nonexistent")
      end

      test "filters prompts with a block" do
        text_prompts = @collection.filter { |p| p.name.include?("text") }
        assert_equal 1, text_prompts.size
        assert_equal "summarize_text", text_prompts.first.name
      end

      test "returns all prompt names" do
        assert_equal %w[summarize_text greeting], @collection.names
      end

      test "checks if collection contains a prompt" do
        assert @collection.contains?("greeting")
        refute @collection.contains?("nonexistent")
      end

      test "enumerates all prompts" do
        names = []
        @collection.each { |prompt| names << prompt.name }
        assert_equal %w[summarize_text greeting], names
      end

      test "prompt gets required arguments" do
        prompt = @collection.find("summarize_text")
        required = prompt.required_arguments
        assert_equal 1, required.size
        assert_equal "text", required.first["name"]
      end

      test "prompt gets optional arguments" do
        prompt = @collection.find("summarize_text")
        optional = prompt.optional_arguments
        assert_equal 1, optional.size
        assert_equal "style", optional.first["name"]
      end

      test "prompt checks for specific argument" do
        prompt = @collection.find("greeting")
        assert prompt.has_argument?("name")
        refute prompt.has_argument?("nonexistent")
      end

      test "prompt generates hash representation" do
        prompt = @collection.find("greeting")
        hash = prompt.to_h
        assert_equal "greeting", hash["name"]
        assert_equal "Generates a personalized greeting message", hash["description"]
        assert_equal 2, hash["arguments"].size
      end
    end
  end
end

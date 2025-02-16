# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ResourcesBankTest < Minitest::Test
    def setup
      @resources_bank = ResourcesBank
      @resources_bank.instance_variable_set(:@resources, {}) # Clear resources
      @resources_bank.instance_variable_set(:@templates, {}) # Clear templates

      # Register some test resources
      @resource1 = Resource.new(uri: "file:///test1.txt", name: "Test File 1", description: "Test file 1", mime_type: "text/plain", size: 0)
      @resource2 = Resource.new(uri: "file:///test2.txt", name: "Test File 2", description: "Test file 2", mime_type: "text/plain", size: 0)
      @resources_bank.register_resource(@resource1.uri, Content::Resource.new("file:///test1.txt", "text/plain", text: "This is test file 1"))
      @resources_bank.register_resource(@resource2.uri, Content::Resource.new("file:///test2.txt", "text/plain", text: "This is test file 2"))

      # Register some test templates
      @template1 = Resource.new(uri: "file:///{path}", name: "Project Files", description: "Access files in the project directory", mime_type: "application/octet-stream", size: 0)
      @resources_bank.register_template(@template1.uri, @template1)
    end

    # def test_handle_list_resources
    #   result = @resources_bank.handle_list_resources({})
    #   assert_equal 2, result[:resources].size
    #   assert_equal @resource1.to_h, result[:resources][0]
    #   assert_equal @resource2.to_h, result[:resources][1]
    # end

    def test_handle_read_resource
      result = @resources_bank.handle_read_resource({ "uri" => "file:///test1.txt" })
      assert_equal "file:///test1.txt", result[:contents][0][:uri]
      assert_equal "text/plain", result[:contents][0][:mimeType]
      assert_equal "This is test file 1", result[:contents][0][:text]

      # Test resource not found
      result = @resources_bank.handle_read_resource({ "uri" => "file:///nonexistent.txt" })
      assert_equal -32002, result[:error][:code]
      assert_equal "Resource not found", result[:error][:message]
    end

    def test_handle_list_templates
      result = @resources_bank.handle_list_templates({})
      assert_equal 1, result[:resourceTemplates].size
      assert_equal({
        uriTemplate: @template1.uri,
        name: @template1.name,
        description: @template1.description,
        mimeType: @template1.mime_type
      }, result[:resourceTemplates][0])
    end
  end
end

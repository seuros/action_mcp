# frozen_string_literal: true

class TypedAdditionalPropsTool < ApplicationMCPTool
  tool_name "typed_additional_props"
  title "Typed Additional Properties Demo"
  description "Tool that accepts additional properties but restricts them to strings"

  # Define core properties
  property :action, type: "string", description: "Action to perform", required: true

  # Allow additional properties but restrict them to strings
  additional_properties({ "type" => "string" })

  def perform
    core_action = action
    extra_params = additional_params

    render text: "🎯 Action: #{core_action}"

    if extra_params.any?
      render text: "📝 Additional String Parameters:"
      extra_params.each do |key, value|
        render text: "  #{key}: \"#{value}\""
      end
    else
      render text: "📝 No additional parameters provided"
    end

    render structured: {
      action: core_action,
      additional_strings: extra_params
    }
  end
end

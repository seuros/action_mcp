# frozen_string_literal: true

class FixedFormatCodeTool < ApplicationMCPTool
  # Setting a specific name for the tool
  tool_name "format_source_fixed"
  title "Code Formatter"
  description "Format source code according to a specific style"
  read_only
  idempotent

  # Define properties with proper schema structure
  property :source_code, type: "string", description: "The code to be formatted", required: true
  property :language, type: "string", description: "Programming language (e.g., javascript, ruby, python)",
                      required: true
  property :style, type: "string", description: "Formatting style or formatter rules (optional)"

  # Performs the code formatting
  def perform
    # Simple formatting implementation for demonstration
    # In a real implementation, this would use language-specific formatters

    # Basic formatting: remove extra spaces
    formatted_code = source_code.gsub(/\s+/, " ")

    # Style-specific formatting could be applied based on language and style parameters
    case language.downcase
    when "javascript", "js"
      # For JavaScript, replace multiple spaces with single space in specific contexts
      formatted_code = formatted_code.gsub(/\s*\{\s*/, " { ")
                                     .gsub(/\s*\}\s*/, " } ")
                                     .gsub(/\s*\(\s*/, "(")
                                     .gsub(/\s*\)\s*/, ") ")
                                     .gsub(/\s*;\s*/, "; ")
                                     .gsub(/\s*,\s*/, ", ")
                                     .gsub(/\s*=\s*/, " = ")
                                     .strip
    when "ruby"
      # Some basic Ruby formatting rules
      formatted_code = formatted_code.gsub(/\s*\{\s*/, " { ")
                                     .gsub(/\s*\}\s*/, " } ")
                                     .gsub(/\s*\(\s*/, "(")
                                     .gsub(/\s*\)\s*/, ")")
                                     .gsub(/\s*,\s*/, ", ")
                                     .gsub(/\s*=\s*/, " = ")
                                     .strip
    when "python"
      # Some basic Python formatting
      formatted_code = formatted_code.gsub(/\s*:\s*/, ": ")
                                     .gsub(/\s*,\s*/, ", ")
                                     .gsub(/\s*=\s*/, " = ")
                                     .strip
    end

    # Return the formatted code
    render text: formatted_code
  end
end

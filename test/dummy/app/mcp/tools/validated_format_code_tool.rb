# frozen_string_literal: true

class ValidatedFormatCodeTool < ApplicationMCPTool
  # Define tool metadata
  tool_name "format_source"
  description "Format source code according to a specific coding style"

  # Define properties with proper schema structure
  property :source_code, type: "string", description: "The source code to be formatted", required: true
  property :language, type: "string", description: "Programming language (e.g., javascript, ruby, python)",
                      required: true
  property :style, type: "string", description: "Formatting style or formatter rules (optional)"

  # Performs the code formatting
  def perform
    # Simple formatting implementation for demonstration
    # In a real implementation, this would use language-specific formatters

    # Basic formatting: compact multiple spaces
    formatted_code = source_code.gsub(/\s+/, " ")

    # Apply language-specific formatting
    formatted_code = case language.downcase
    when "javascript", "js"
                       # For JavaScript, apply specific formatting rules
                       format_javascript(formatted_code)
    when "ruby"
                       # Ruby-specific formatting
                       format_ruby(formatted_code)
    when "python"
                       # Python-specific formatting
                       format_python(formatted_code)
    else
                       # Generic formatting for other languages
                       format_generic(formatted_code)
    end

    # Return the formatted code
    render text: formatted_code
  end

  private

  def format_javascript(code)
    # Simple JavaScript formatting
    code.gsub(/\s*\{\s*/, " { ")
        .gsub(/\s*\}\s*/, " } ")
        .gsub(/\s*\(\s*/, "(")
        .gsub(/\s*\)\s*/, ") ")
        .gsub(/\s*;\s*/, "; ")
        .gsub(/\s*,\s*/, ", ")
        .gsub(/\s*=\s*/, " = ")
        .strip
  end

  def format_ruby(code)
    # Simple Ruby formatting
    code.gsub(/\s*\{\s*/, " { ")
        .gsub(/\s*\}\s*/, " } ")
        .gsub(/\s*\(\s*/, "(")
        .gsub(/\s*\)\s*/, ")")
        .gsub(/\s*,\s*/, ", ")
        .gsub(/\s*=\s*/, " = ")
        .gsub(/\s*do\s*/, " do ")
        .gsub(/\s*end\s*/, " end ")
        .strip
  end

  def format_python(code)
    # Simple Python formatting
    code.gsub(/\s*:\s*/, ": ")
        .gsub(/\s*,\s*/, ", ")
        .gsub(/\s*=\s*/, " = ")
        .gsub(/\s*def\s+/, "def ")
        .gsub(/\s*class\s+/, "class ")
        .strip
  end

  def format_generic(code)
    # Generic formatting for other languages
    code.gsub(/\s*\{\s*/, " { ")
        .gsub(/\s*\}\s*/, " } ")
        .gsub(/\s*\(\s*/, "(")
        .gsub(/\s*\)\s*/, ")")
        .gsub(/\s*,\s*/, ", ")
        .gsub(/\s*=\s*/, " = ")
        .strip
  end
end

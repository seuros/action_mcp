# frozen_string_literal: true

# app/models/concerns/mcp_message_inspect.rb
module ActionMCP
  module MCPMessageInspect
    extend ActiveSupport::Concern

  def inspect(show_data: false)
    if show_data
      super() # Rails default inspect
    else
      build_summary_inspect
    end
  end

  private

  def build_summary_inspect
    case message_type
    when "request"
      format_request_summary
    when "response", "error"
      format_response_summary
    when "notification"
      format_notification_summary
    else
      format_default_summary
    end
  end

  def format_request_summary
    method = data&.dig("method")
    formatted = "#<Message #{id}: REQUEST #{jsonrpc_id} -> #{method}>"
    console? ? colorize(formatted, :blue) : formatted
  end

  def format_response_summary
    formatted = "#<Message #{id}: #{message_type.upcase} #{jsonrpc_id}>"
    if console?
      color = message_type == "error" ? :red : :green
      colorize(formatted, color)
    else
      formatted
    end
  end

  def format_notification_summary
    method = data&.dig("method")
    formatted = "#<Message #{id}: NOTIFICATION -> #{method}>"
    console? ? colorize(formatted, :yellow) : formatted
  end

  def format_default_summary
    formatted = "#<Message #{id}: #{message_type.upcase}>"
    console? ? colorize(formatted, :gray) : formatted
  end

  def console?
    # Check if we're in a Rails console environment
    defined?(Rails::Console)
  end

  def colorize(text, color)
    colors = {
      blue: "\e[34m",
      green: "\e[32m",
      red: "\e[31m",
      yellow: "\e[33m",
      gray: "\e[90m"
    }

    "#{colors[color]}#{text}\e[0m"
  end
  end
end

# frozen_string_literal: true

# app/models/concerns/mcp_console_helpers.rb
module MCPConsoleHelpers
  extend ActiveSupport::Concern

  class_methods do
    def pretty_messages(session_or_messages, limit: 10)
      messages = if session_or_messages.respond_to?(:messages)
                   session_or_messages.messages.order(:created_at).last(limit)
      else
                   session_or_messages.last(limit)
      end

      messages.each do |msg|
        puts msg.inspect
        puts "  └─ #{msg.data['method']}" if msg.data&.dig("method")
        puts
      end
    end

    def message_flow(session, limit: 50)
      puts "\nMCP Message Flow:"
      puts "Session ID: #{session.id}"
      puts "Protocol: #{session.protocol_version}"
      puts "─" * 70

      session.messages.order(:created_at).last(limit).each do |msg|
        time = msg.created_at.strftime("%H:%M:%S.%3N")
        arrow = msg.direction == "client" ? "→" : "←"
        direction_label = msg.direction == "client" ? "CLIENT" : "SERVER"

        if ActionMCP::ConsoleDetector.in_console?
          color_code = case msg.message_type
          when "request" then "\e[34m"
          when "response" then "\e[32m"
          when "error" then "\e[31m"
          when "notification" then "\e[33m"
          else "\e[90m"
          end
          puts "#{time} #{color_code}#{direction_label}\e[0m #{arrow} #{msg.inspect}"
        else
          puts "#{time} #{direction_label} #{arrow} #{msg.inspect}"
        end
      end

      puts "─" * 70
    end

    def message_stats(session)
      stats = session.messages.group(:message_type, :direction).count

      puts "\nMessage Statistics:"
      puts "─" * 40

      stats.each do |(type, direction), count|
        puts "#{type.ljust(15)} #{direction.ljust(10)} #{count}"
      end

      puts "─" * 40
      puts "Total: #{session.messages.count}"
    end
  end

  def message_flow(limit: 50)
    self.class.message_flow(self, limit: limit)
  end
end

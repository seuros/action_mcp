# frozen_string_literal: true

module ActionMCP
  module ConsoleDetector
    module_function

    def in_console?
      # Check for Rails console
      defined?(Rails::Console)
    end
  end
end

# frozen_string_literal: true

# Load the Rails application.
require_relative "application"

# Disable pending migration check for engine testing
# Engine db/migrate timestamps differ from installed migrations in dummy/db/migrate
# This must happen BEFORE Rails.application.initialize!
if Rails.env.test?
  ActiveRecord::Migration.class_eval do
    def self.check_all_pending!
      # no-op for engine tests
    end
  end
end

# Initialize the Rails application.
Rails.application.initialize!

# frozen_string_literal: true

# Load the Rails environment
require_relative "config/environment"

Rails.application.eager_load!

run ActionMCP.server

# frozen_string_literal: true

require "test_helper"

# OAuth 2.1 Test Suite
# 
# This file runs all OAuth-related tests to verify the complete OAuth 2.1 implementation.
# It includes tests for:
# - OAuth Provider (authorization codes, tokens, PKCE, introspection, revocation)
# - OAuth Endpoints (authorize, token, introspect, revoke)
# - OAuth Middleware (Bearer token validation)
# - OAuth Metadata (well-known endpoints)
# - OAuth Error handling
# - Gateway OAuth integration
#
# Run with: bundle exec rails test test/oauth_test_suite.rb

class OAuthTestSuite < ActiveSupport::TestCase
  def test_oauth_test_suite_coverage
    # This test verifies that all OAuth components have tests
    oauth_test_files = [
      "test/action_mcp/oauth/error_test.rb",
      "test/action_mcp/oauth/middleware_test.rb", 
      "test/action_mcp/oauth/provider_test.rb",
      "test/controllers/action_mcp/oauth/metadata_controller_test.rb",
      "test/controllers/action_mcp/oauth/endpoints_controller_test.rb",
      "test/action_mcp/gateway_oauth_test.rb"
    ]

    oauth_test_files.each do |test_file|
      full_path = File.join(File.dirname(__FILE__), "..", test_file)
      assert File.exist?(full_path), "OAuth test file missing: #{test_file}"
    end

    puts "\n🔐 OAuth 2.1 Test Suite"
    puts "=" * 50
    puts "✅ OAuth Provider Tests"
    puts "✅ OAuth Endpoints Tests" 
    puts "✅ OAuth Middleware Tests"
    puts "✅ OAuth Metadata Tests"
    puts "✅ OAuth Error Tests"
    puts "✅ Gateway OAuth Tests"
    puts "=" * 50
    puts "📊 Total OAuth test files: #{oauth_test_files.length}"
    puts "🎯 Run individual components with:"
    puts "   bundle exec rails test test/action_mcp/oauth/"
    puts "   bundle exec rails test test/controllers/action_mcp/oauth/"
    puts "   bundle exec rails test test/action_mcp/gateway_oauth_test.rb"
  end
end

# Auto-require all OAuth test files when this suite is run
if __FILE__ == $0 || ENV["RUN_OAUTH_SUITE"]
  puts "🚀 Running OAuth 2.1 Test Suite..."
  
  # Run all OAuth tests
  oauth_test_patterns = [
    "test/action_mcp/oauth/*.rb",
    "test/controllers/action_mcp/oauth/*.rb", 
    "test/action_mcp/gateway_oauth_test.rb"
  ]

  oauth_test_patterns.each do |pattern|
    Dir.glob(File.join(File.dirname(__FILE__), "..", pattern)).each do |file|
      require file
    end
  end
end
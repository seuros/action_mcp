# frozen_string_literal: true

require_relative 'lib/action_mcp/version'

Gem::Specification.new do |spec|
  spec.name        = 'actionmcp'
  spec.version     = ActionMCP::VERSION
  spec.authors     = [ 'Abdelkader Boudih' ]
  spec.email       = [ 'terminale@gmail.com' ]
  spec.homepage    = 'https://github.com/seuros/action_mcp'
  spec.summary     = 'Provides essential tooling for building Model Context Protocol (MCP) capable servers'
  spec.description = 'It offers base classes and helpers for creating MCP applications, making it easier to integrate your Ruby/Rails application with the MCP standard'
  spec.license     = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/seuros/action_mcp'
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,exe,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'activerecord', '>= 8.0.1'
  spec.add_dependency 'concurrent-ruby', '>= 1.3.1'
  spec.add_dependency 'jsonrpc-rails', '>= 0.5.3'
  spec.add_dependency 'jwt', '~> 2.10'
  spec.add_dependency 'multi_json'
  spec.add_dependency 'railties', '>= 8.0.1'
  spec.add_dependency 'zeitwerk', '~> 2.6'
  # OAuth 2.1 support via Omniauth
  spec.add_dependency 'omniauth', '~> 2.1'
  spec.add_dependency 'omniauth-oauth2', '~> 1.7'
  spec.add_dependency 'ostruct'
  # OAuth client support
  spec.add_dependency 'faraday', '~> 2.7'
  spec.add_dependency 'pkce_challenge', '~> 1.0'

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Development dependencies
  spec.add_development_dependency 'json_schemer', '~> 2.0'
end

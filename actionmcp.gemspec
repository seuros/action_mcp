# frozen_string_literal: true

require_relative 'lib/action_mcp/version'

Gem::Specification.new do |spec|
  spec.name        = 'actionmcp'
  spec.version     = ActionMCP::VERSION
  spec.authors     = [ 'Abdelkader Boudih' ]
  spec.email       = [ 'terminale@gmail.com' ]
  spec.homepage    = 'https://github.com/seuros/action_mcp'
  spec.summary     = 'Lightweight Model Context Protocol (MCP) server toolkit for Ruby/Rails'
  spec.description = 'A streamlined, production-focused toolkit for building MCP servers in Rails applications. Provides essential base classes, authentication gateways, and HTTP transport with minimal dependencies.'
  spec.license     = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/seuros/action_mcp'
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,exe,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'activejob', '>= 8.1.0'
  spec.add_dependency 'activerecord', '>= 8.1.0'
  spec.add_dependency 'concurrent-ruby', '>= 1.3.1'
  spec.add_dependency 'jsonrpc-rails', '>= 0.5.3'
  spec.add_dependency 'multi_json'
  spec.add_dependency 'railties', '>= 8.1.0'
  spec.add_dependency 'zeitwerk', '~> 2.6'
  spec.add_dependency 'state_machines-activerecord', '>= 0.100.0'

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Development dependencies
  spec.add_development_dependency 'json_schemer', '~> 2.0'
end

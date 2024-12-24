# frozen_string_literal: true

require_relative 'lib/action_mcp/version'

Gem::Specification.new do |spec|
  spec.name        = 'actionmcp'
  spec.version     = ActionMCP::VERSION
  spec.authors     = [ 'Abdelkader Boudih' ]
  spec.email       = [ 'terminale@gmail.com' ]
  spec.homepage    = 'Project URL'
  spec.summary     = 'Provides essential tooling for building Model Context Protocol (MCP) capable servers'
  spec.description = 'It offers base classes and helpers for creating MCP applications, making it easier to integrate your Ruby/Rails application with the MCP standard'
  spec.license     = 'Privsate'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata['allowed_push_host'] = 'https://gems.seuros.com'

  spec.metadata['homepage_uri'] = spec.homepage
  # spec.metadata['source_code_uri'] = "Put your gem's public repo URL here."
  # spec.metadata['changelog_uri'] = "Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{exe,lib}/**/*', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'activemodel', '>= 8.0.1'
  spec.add_dependency 'activesupport', '>= 8.0.1'
  spec.add_dependency 'multi_json'

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
end

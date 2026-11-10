# frozen_string_literal: true

# One status panel per service; tools point at a concrete service URI.
class ServiceStatusTemplate < ApplicationMCPResTemplate
  description "Status panel for a single service"
  uri_template "ui://services/{service}"
  mime_type :mcp_app

  parameter :service, description: "Service name", required: true

  def resolve
    render_ui(text: <<~HTML)
      <!doctype html>
      <html lang="en"><body><h1>#{ERB::Util.html_escape(service)} status</h1></body></html>
    HTML
  end
end

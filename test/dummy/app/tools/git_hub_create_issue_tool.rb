# frozen_string_literal: true

class GitHubCreateIssueTool < ApplicationTool
  # Force a specific name (else would default to "git_hub_create_issue")
  tool_name "github_create_issue"
  description "Create a GitHub issue"

  property :title, type: "string", description: "Issue title"
  property :body, type: "string", description: "Issue body"
  collection :labels, type: "string", description: "Issue labels"

  def call
    issue_url = "https://github.com/fake/repo/issues/#{rand(1000..9999)}"
    render_text("Issue created: #{issue_url} with labels: #{labels}.joins(' ')) and title: #{title}")
  end
end

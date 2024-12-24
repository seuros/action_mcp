# frozen_string_literal: true

class GitHubCreateIssueTool < ApplicationTool
  tool_name "github_create_issue"
  description "Create a GitHub issue"

  property :title, type: "string", description: "Issue title"
  property :body, type: "string", description: "Issue body"
  property :labels, type: "array", description: "Issue labels", items: { type: "string" }
end

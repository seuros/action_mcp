# frozen_string_literal: true

class ChecksumCheckerTool < ApplicationMCPTool
  description "Check checksum256 of a file"

  collection :files, description: "List of Files", type: "string"

  def perform
    result = files.map(&:hash)
    render text: result.to_json
  end
end

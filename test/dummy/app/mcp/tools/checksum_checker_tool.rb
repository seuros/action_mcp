# frozen_string_literal: true

class ChecksumCheckerTool < ApplicationTool
  description "Check checksum256 of a file"

  collection :files, description: "List of Files", type: "string"

  def call
    result = files.map(&:hash)
    render_text(result.to_json)
  end
end

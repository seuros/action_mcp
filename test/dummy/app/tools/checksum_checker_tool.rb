# frozen_string_literal: true

class ChecksumCheckerTool < ApplicationTool
  description "check checksum256 of a file"

  collection :files, description: "List of Files" do
    property :file, required: true, description: "eeee"
    property :checksum, required: true, description: "eeee"
  end
end

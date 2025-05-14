# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class UriAmbiguityCheckerTest < ActiveSupport::TestCase
    class Probe < ActionMCP::ResourceTemplate; include UriAmbiguityChecker; end

    test "matrix" do
      load_fixture("uri_ambiguity_cases").each do |row|
        assert_equal row["expected"],
                     Probe.are_potentially_ambiguous?(row["pattern1"], row["pattern2"]),
                     "#{row['pattern1']} vs #{row['pattern2']}"
      end
    end
  end
end

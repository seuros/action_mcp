# frozen_string_literal: true

require "tmpdir"

# Gives every generator test its own temporary destination. destination_root is a
# class_attribute shared by all generator test classes, so a per-test directory keeps
# concurrent runs (parallelize, padded_cell) from racing on rm_rf/mkdir_p.
module GeneratorTestDestination
  extend ActiveSupport::Concern

  included do
    destination File.expand_path("../../tmp/generator_test_output", __dir__)

    setup do
      self.destination_root = Dir.mktmpdir("action_mcp_#{self.class.name.demodulize.underscore}")
      prepare_destination
    end

    teardown do
      FileUtils.rm_rf(destination_root)
    end
  end

  # app/mcp/<directory>/<name>_<suffix>.rb, without doubling a suffix already in the name.
  def generated_component_path(name, suffix, directory)
    base = name.underscore
    file = base.end_with?("_#{suffix}") ? base : "#{base}_#{suffix}"
    File.join(destination_root, "app/mcp/#{directory}/#{file}.rb")
  end
end

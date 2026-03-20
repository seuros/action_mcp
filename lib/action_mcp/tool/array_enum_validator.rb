# frozen_string_literal: true

class ActionMCP::Tool::ArrayEnumValidator < ActiveModel::Validator
  def validate(record)
    invalid_values = record.send(options[:prop_name]) - options[:enum]

    return if invalid_values.empty?

    record.errors.add(options[:prop_name], "contains invalid value(s) #{invalid_values.inspect}, allowed values are: #{options[:enum].inspect}")
  end
end

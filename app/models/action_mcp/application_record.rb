# frozen_string_literal: true

module ActionMCP
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end

# frozen_string_literal: true

class MockOrder
  def self.find_by(id:)
    new(id: id) if id.to_i.positive?
  end

  attr_reader :id

  def initialize(id:)
    @id = id
  end

  def to_json(*_args)
    { id: id }.to_json
  end
end

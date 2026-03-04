# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "users"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "integer", pk = true, null = false },
#   { name = "active", type = "boolean", default = true },
#   { name = "api_key", type = "string" },
#   { name = "created_at", type = "datetime", null = false },
#   { name = "email", type = "string" },
#   { name = "last_login_at", type = "datetime" },
#   { name = "name", type = "string" },
#   { name = "password_digest", type = "string" },
#   { name = "updated_at", type = "datetime", null = false }
# ]
#
# indexes = [
#   { name = "index_users_on_email", columns = ["email"], unique = true },
#   { name = "index_users_on_api_key", columns = ["api_key"], unique = true }
# ]
#
# [callbacks]
# before_create = [{ method = "generate_api_key" }]
#
# notes = ["active:NOT_NULL", "api_key:NOT_NULL", "email:NOT_NULL", "name:NOT_NULL", "password_digest:NOT_NULL", "api_key:LIMIT", "email:LIMIT", "name:LIMIT", "password_digest:LIMIT"]
# <rails-lens:schema:end>
class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  before_create :generate_api_key

  scope :active, -> { where(active: true) }

  def touch_last_login!
    update!(last_login_at: Time.current)
  end

  def regenerate_api_key!
    update!(api_key: SecureRandom.hex(32))
  end

  private

  def generate_api_key
    self.api_key ||= SecureRandom.hex(32)
  end
end

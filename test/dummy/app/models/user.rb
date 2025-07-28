# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "users"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "integer", primary_key = true, nullable = false },
#   { name = "email", type = "string", nullable = true },
#   { name = "name", type = "string", nullable = true },
#   { name = "created_at", type = "datetime", nullable = false },
#   { name = "updated_at", type = "datetime", nullable = false },
#   { name = "password_digest", type = "string", nullable = true },
#   { name = "api_key", type = "string", nullable = true },
#   { name = "active", type = "boolean", nullable = true, default = "1" },
#   { name = "last_login_at", type = "datetime", nullable = true }
# ]
#
# indexes = [
#   { name = "index_users_on_email", columns = ["email"], unique = true },
#   { name = "index_users_on_api_key", columns = ["api_key"], unique = true }
# ]
#
# == Notes
# - Column 'email' should probably have NOT NULL constraint
# - Column 'name' should probably have NOT NULL constraint
# - Column 'password_digest' should probably have NOT NULL constraint
# - Column 'api_key' should probably have NOT NULL constraint
# - Column 'active' should probably have NOT NULL constraint
# - String column 'email' has no length limit - consider adding one
# - String column 'name' has no length limit - consider adding one
# - String column 'password_digest' has no length limit - consider adding one
# - String column 'api_key' has no length limit - consider adding one
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

class AddAuthenticationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_digest, :string
    add_column :users, :api_key, :string
    add_column :users, :active, :boolean, default: true
    add_column :users, :last_login_at, :datetime

    add_index :users, :api_key, unique: true
    add_index :users, :email, unique: true
  end
end

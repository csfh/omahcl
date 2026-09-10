class AddEmailVerifiedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_verified_at, :datetime

    reversible do |direction|
      direction.up { execute "UPDATE users SET email_verified_at = created_at" }
    end
  end
end

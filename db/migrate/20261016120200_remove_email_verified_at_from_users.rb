class RemoveEmailVerifiedAtFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :email_verified_at, :datetime
  end
end

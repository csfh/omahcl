class GrantOmarchyChristofferAdmin < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE users
      SET admin = TRUE
      WHERE email_address = 'omarchy@christofferhallas.com'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE users
      SET admin = FALSE
      WHERE email_address = 'omarchy@christofferhallas.com'
    SQL
  end
end

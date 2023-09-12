class DropEmailSubscriptions < ActiveRecord::Migration[7.0]
  def up
    drop_table :email_subscriptions
  end
end

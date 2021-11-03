class MoveUnmigratedUsersToNewTable < ActiveRecord::Migration[6.1]
  def change
    create_table :unmigrated_oidc_users do |t|
      t.string  :sub, null: false
      t.string  :email
      t.boolean :email_verified
      t.boolean :has_unconfirmed_email
      t.jsonb   :transition_checker_state

      t.timestamps default: -> { "now()" }, null: false
    end
  end
end

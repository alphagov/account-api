class RemoveOldTransitionCheckerState < ActiveRecord::Migration[6.1]
  def up
    change_table :oidc_users, bulk: true do |t|
      t.remove :has_received_transition_checker_onboarding_email
      t.remove :transition_checker_state
    end

    drop_table :unmigrated_oidc_users
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

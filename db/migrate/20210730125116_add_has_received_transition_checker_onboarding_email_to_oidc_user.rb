class AddHasReceivedTransitionCheckerOnboardingEmailToOidcUser < ActiveRecord::Migration[6.1]
  def change
    add_column :oidc_users, :has_received_transition_checker_onboarding_email, :boolean, default: true, null: false
  end
end

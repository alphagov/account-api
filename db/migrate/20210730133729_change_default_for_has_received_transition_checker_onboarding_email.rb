class ChangeDefaultForHasReceivedTransitionCheckerOnboardingEmail < ActiveRecord::Migration[6.1]
  def change
    change_column_default :oidc_users, :has_received_transition_checker_onboarding_email, from: true, to: false
  end
end

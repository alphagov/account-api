class RemoveCookieAndFeedbackConsentFromOidcUsers < ActiveRecord::Migration[7.0]
  def change
    change_table :oidc_users, bulk: true do |t|
      t.remove :cookie_consent, type: :boolean
      t.remove :feedback_consent, type: :boolean
    end
  end
end

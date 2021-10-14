class AddCookieAndFeedbackConsentToOidcUser < ActiveRecord::Migration[6.1]
  def change
    change_table :oidc_users, bulk: true do |t|
      t.boolean :cookie_consent, null: true
      t.boolean :feedback_consent, null: true
    end
  end
end

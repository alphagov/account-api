class CreateEmailSubscriptions < ActiveRecord::Migration[6.1]
  def change
    create_table :email_subscriptions do |t|
      t.references :oidc_user,  null: false
      t.string     :name,       null: false
      t.string     :topic_slug, null: false
      t.string     :email_alert_api_subscription_id

      t.timestamps
    end

    add_index :email_subscriptions, %i[oidc_user_id name], unique: true
  end
end

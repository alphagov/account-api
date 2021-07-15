class AddLocalAttributeFieldsToOidcUser < ActiveRecord::Migration[6.1]
  def change
    add_column :local_attributes, :migrated, :boolean, default: false, null: false

    change_table :oidc_users, bulk: true do |t|
      t.string  :email
      t.boolean :email_verified
      t.boolean :has_unconfirmed_email
      t.boolean :oidc_users
      t.jsonb   :transition_checker_state
    end
  end
end

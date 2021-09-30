class AddLegacySubToOidcUser < ActiveRecord::Migration[6.1]
  def change
    add_column :oidc_users, :legacy_sub, :string, null: true
  end
end

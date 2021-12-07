class RemoveHasUnconfirmedEmailFromOidcUsers < ActiveRecord::Migration[6.1]
  def change
    remove_column :oidc_users, :has_unconfirmed_email, :boolean
  end
end

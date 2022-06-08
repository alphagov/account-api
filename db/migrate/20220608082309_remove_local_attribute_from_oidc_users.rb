class RemoveLocalAttributeFromOidcUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :oidc_users, :local_attribute, :boolean
  end
end

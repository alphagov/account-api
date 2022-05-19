class AddLocalAttributeToOicdUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :oidc_users, :local_attribute, :string
  end
end

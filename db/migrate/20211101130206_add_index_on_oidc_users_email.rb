class AddIndexOnOidcUsersEmail < ActiveRecord::Migration[6.1]
  def change
    add_index :oidc_users, :email, unique: true
  end
end

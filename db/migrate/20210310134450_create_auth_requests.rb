class CreateAuthRequests < ActiveRecord::Migration[6.1]
  def change
    create_table :auth_requests do |t|
      t.string :oauth_state, null: false
      t.string :oidc_nonce,  null: false
      t.string :redirect_path

      t.timestamps null: false
    end
  end
end

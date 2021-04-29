class CreateOidcUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :oidc_users do |t|
      t.string :sub, null: false

      t.timestamps default: -> { "now()" }, null: false
    end

    add_index :oidc_users, :sub, unique: true
  end
end

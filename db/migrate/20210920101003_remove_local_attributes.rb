class RemoveLocalAttributes < ActiveRecord::Migration[6.1]
  def change
    remove_index :local_attributes, %i[oidc_user_id name], unique: true

    drop_table :local_attributes do |t|
      t.references :oidc_user, null: false
      t.string     :name,      null: false
      t.jsonb      :value,     null: false
      t.boolean    :migrated,  null: false, default: false

      t.timestamps default: -> { "now()" }, null: false
    end
  end
end

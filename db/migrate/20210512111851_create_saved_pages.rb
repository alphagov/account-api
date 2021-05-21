class CreateSavedPages < ActiveRecord::Migration[6.1]
  def change
    create_table :saved_pages do |t|
      t.references :oidc_user, null: false
      t.string     :page_path, null: false

      t.timestamps
    end

    add_index :saved_pages, %i[oidc_user_id page_path], unique: true
  end
end

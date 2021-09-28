class RemoveSavedPages < ActiveRecord::Migration[6.1]
  def change
    remove_index :saved_pages, %i[oidc_user_id page_path], unique: true
    remove_index :saved_pages, %i[oidc_user_id]

    drop_table :saved_pages do |t|
      t.bigint     :oidc_user_id,   null: false
      t.string     :page_path,      null: false
      t.uuid       :content_id, null: false
      t.string     :title
      t.datetime   :public_updated_at

      t.timestamps default: -> { "now()" }, null: false
    end
  end
end

class AddContentStoreDataToSavedPage < ActiveRecord::Migration[6.1]
  def change
    change_table :saved_pages, bulk: true do |t|
      t.uuid   :content_id, null: false
      t.string :title
    end
  end
end

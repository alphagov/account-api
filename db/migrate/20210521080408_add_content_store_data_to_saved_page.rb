class AddContentStoreDataToSavedPage < ActiveRecord::Migration[6.1]
  def change
    # rubocop:disable Rails/NotNullColumn
    change_table :saved_pages, bulk: true do |t|
      t.uuid   :content_id, null: false
      t.string :title
    end
    # rubocop:enable Rails/NotNullColumn
  end
end

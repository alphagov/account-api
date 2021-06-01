class AddPublicUpdatedAtToSavedPage < ActiveRecord::Migration[6.1]
  def change
    add_column :saved_pages, :public_updated_at, :datetime
  end
end

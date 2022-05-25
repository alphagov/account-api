class RemoveUniqueSubIndexFromTombstones < ActiveRecord::Migration[7.0]
  def change
    remove_index :tombstones, column: :sub
    add_index :tombstones, :sub, if_not_exists: true
  end
end

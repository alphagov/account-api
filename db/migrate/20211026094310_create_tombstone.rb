class CreateTombstone < ActiveRecord::Migration[6.1]
  def change
    create_table :tombstones do |t|
      t.string :sub, null: false

      t.timestamps default: -> { "now()" }, null: false
    end

    add_index :tombstones, :sub, unique: true
  end
end

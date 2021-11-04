class CreateSensitiveExceptions < ActiveRecord::Migration[6.1]
  def change
    create_table :sensitive_exceptions do |t|
      t.string :message
      t.string :full_message
      t.timestamps default: -> { "now()" }, null: false
    end
  end
end

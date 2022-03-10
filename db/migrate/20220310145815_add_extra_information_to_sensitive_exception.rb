class AddExtraInformationToSensitiveException < ActiveRecord::Migration[7.0]
  def change
    add_column :sensitive_exceptions, :extra_info, :string
  end
end

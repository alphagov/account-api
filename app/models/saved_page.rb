class SavedPage < ApplicationRecord
  belongs_to :oidc_user

  def to_hash
    {
      "page_path" => page_path,
    }
  end
end

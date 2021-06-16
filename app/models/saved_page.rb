class SavedPage < ApplicationRecord
  belongs_to :oidc_user

  validates :content_id, presence: true
  validates :page_path, uniqueness: { scope: :oidc_user_id }, presence: true, absolute_path: true

  def to_hash
    {
      "page_path" => page_path,
      "content_id" => content_id,
      "title" => title,
      "public_updated_at" => public_updated_at,
    }.compact
  end

  def self.updates_from_content_item(content_item)
    {
      content_id: content_item.fetch("content_id"),
      title: content_item["title"],
      public_updated_at: content_item["public_updated_at"] ? Time.zone.parse(content_item["public_updated_at"]) : nil,
    }
  end
end

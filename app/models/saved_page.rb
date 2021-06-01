class SavedPage < ApplicationRecord
  belongs_to :oidc_user

  validates :page_path, uniqueness: { scope: :oidc_user_id }, presence: true

  validate :page_path_is_valid_path

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

private

  def page_path_is_valid_path
    errors.add(:page_path, :invalid_path, message: "must only include URL path") unless is_valid_path?
  end

  def is_valid_path?
    page_path&.starts_with?("/") && URI(page_path).path == page_path
  rescue StandardError
    false
  end
end

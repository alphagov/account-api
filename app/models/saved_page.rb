class SavedPage < ApplicationRecord
  belongs_to :oidc_user

  validates :page_path, uniqueness: { scope: :oidc_user_id }, presence: true

  validate :page_path_is_valid_path

  def to_hash
    {
      "page_path" => page_path,
      "content_id" => content_id,
      "title" => title,
    }.compact
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

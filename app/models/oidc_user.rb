class OidcUser < ApplicationRecord
  has_many :email_subscriptions, dependent: :destroy
  has_many :saved_pages, dependent: :destroy

  validates :sub, presence: true

  def get_attributes_by_name(names = [])
    names.index_with { |name| self[name] }.compact
  end
end

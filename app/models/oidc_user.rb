class OidcUser < ApplicationRecord
  has_many :email_subscriptions, dependent: :destroy
  has_many :saved_pages, dependent: :destroy

  validates :sub, presence: true

  def get_local_attributes(names = [])
    names.index_with { |name| self[name] }.compact
  end

  def set_local_attributes(values = {})
    update! values
  end
end

class OidcUser < ApplicationRecord
  has_many :email_subscriptions, dependent: :destroy
  has_many :saved_pages, dependent: :destroy

  validates :sub, presence: true

  def self.find_or_create_by_sub!(sub)
    find_or_create_by!(sub: sub)
  rescue ActiveRecord::RecordNotUnique
    find_by!(sub: sub)
  end

  def get_local_attributes(names = [])
    names.index_with { |name| self[name] }.compact
  end
end

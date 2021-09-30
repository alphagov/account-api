class OidcUser < ApplicationRecord
  has_many :email_subscriptions, dependent: :destroy

  validates :sub, presence: true

  def self.find_or_create_by_sub!(sub)
    find_or_create_by!(sub: sub) do |new_user|
      new_user.legacy_sub = sub
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(sub: sub)
  end

  def get_attributes_by_name(names = [])
    names.index_with { |name| self[name] }.compact
  end
end

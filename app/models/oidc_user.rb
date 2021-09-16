class OidcUser < ApplicationRecord
  has_many :email_subscriptions, dependent: :destroy
  has_many :local_attributes, dependent: :destroy
  has_many :saved_pages, dependent: :destroy

  validates :sub, presence: true

  def self.find_or_create_by_sub!(sub)
    find_or_create_by!(sub: sub)
  rescue ActiveRecord::RecordNotUnique
    find_by!(sub: sub)
  end

  def get_local_attributes(names = [])
    values = names.index_with do |name|
      in_model = self[name]
      if in_model.nil?
        local_attributes.find_by(name: name, migrated: false)&.value
      else
        in_model
      end
    end
    values.compact
  end

  def set_local_attributes(values = {})
    transaction do
      unmigrated = local_attributes.where(migrated: false)
      local_attributes_hash = unmigrated.all.map { |attr| [attr.name, attr.value] }.to_h
      update!(local_attributes_hash)
      update!(values)
      unmigrated.update_all(migrated: true)
    end
  end
end

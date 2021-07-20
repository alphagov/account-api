class OidcUser < ApplicationRecord
  has_many :email_subscriptions, dependent: :destroy
  has_many :local_attributes, dependent: :destroy
  has_many :saved_pages, dependent: :destroy

  validates :sub, presence: true

  def get_local_attributes(names = [])
    local_attributes.where(name: names).each_with_object({}) do |attr, hash|
      hash[attr.name] = attr.value
    end
  end

  def set_local_attributes(values = {})
    return if values.empty?

    LocalAttribute.upsert_all(
      values.map { |name, value| { oidc_user_id: id, name: name, value: value, updated_at: Time.zone.now } },
      unique_by: :index_local_attributes_on_oidc_user_id_and_name,
      returning: false,
    )
  end
end

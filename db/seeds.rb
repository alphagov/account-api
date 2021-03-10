# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

return if User.where(name: "Test user").present?

gds_organisation_id = "af07d5a5-df63-4ddc-9383-6a666845ebe9"

User.create!(
  name: "Test user",
  permissions: %w[signin internal_app],
  organisation_content_id: gds_organisation_id,
)

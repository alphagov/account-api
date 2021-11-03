namespace :migration do
  desc "Move unmigrated users to the unmigrated_oidc_users table"
  task move_unmigrated_users_to_new_table: :environment do
    users_to_migrate = OidcUser.where(email_verified: false).where("created_at < ?", Date.new(2021, 10, 28))
    puts "migrating #{users_to_migrate.count}"

    users_to_migrate.each do |user|
      UnmigratedOidcUser.create!(
        sub: user.sub,
        email: user.email,
        email_verified: user.email_verified,
        has_unconfirmed_email: user.has_unconfirmed_email,
        transition_checker_state: user.transition_checker_state,
        created_at: user.created_at,
        updated_at: user.updated_at,
      )
      user.destroy!
    end
  end
end

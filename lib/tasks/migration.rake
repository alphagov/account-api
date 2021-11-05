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

  desc <<~DESC
    Merge a pre-migration and an improperly-created post-migration user

    This is to handle the case where a legacy_subject_id isn't being
    returned from the userinfo, and so we're trying to create a new
    OidcUser record with the same email address as an existing,
    pre-migration, one.

    It will only merge users where:

    - the post-migration user has no legacy_sub or email.
    - the pre-migration user has the same sub and legacy_sub.
    - both users were created on the right sides of the migration.
  DESC
  task :merge_pre_and_post_user, %i[sub legacy_sub] => :environment do |_, args|
    migration_timestamp = Date.new(2021, 10, 28)
    sub = args.fetch(:sub)
    legacy_sub = args.fetch(:legacy_sub)

    post_migration_user = OidcUser.where(sub: sub).where("created_at > ?", migration_timestamp).first
    abort "post-migration user '#{sub}' not found" unless post_migration_user
    abort "post-migration user '#{sub}' already linked to a pre-migration user" if post_migration_user.legacy_sub
    abort "post-migration user '#{sub}' already has an email address" if post_migration_user.email

    pre_migration_user = OidcUser.where(sub: legacy_sub, legacy_sub: legacy_sub).where("created_at < ?", migration_timestamp).first
    abort "pre-migration user '#{legacy_sub}' not found" unless pre_migration_user

    OidcUser.transaction do
      post_migration_user.destroy!
      Tombstone.where(sub: sub).first.destroy!
      pre_migration_user.update!(sub: sub)
    end
  end
end

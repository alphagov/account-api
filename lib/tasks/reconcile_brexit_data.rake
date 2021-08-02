require "json"

namespace :data_cleaning do
  desc "Return Brexit data to subscriber's accounts from email notifications"
  task :fix_brexit_checker_accounts, %i[subscriber_data] => :environment do |_, args|
    parsed_sub_data = JSON.parse(Base64.decode64(args.subscriber_data))

    parsed_sub_data.each do |subscription|
      oidc_user = LocalAttribute.find_by(name: "email", value: subscription["email"]).oidc_user

      oidc_user.update!(has_received_transition_checker_onboarding_email: true)

      email_topic_slug = subscription["slug"]

      LocalAttribute.create!(
        oidc_user: oidc_user,
        name: "transition_checker_state",
        value: {
          "timestamp" => Time.zone.now.to_i,
          "criteria_keys" => subscription["brexit_checklist_criteria"],
          "email_topic_slug" => email_topic_slug,
        },
      )

      EmailSubscription.create!(
        oidc_user: oidc_user,
        name: "transition-checker-results",
        topic_slug: email_topic_slug,
      ).reactivate_if_confirmed!
    end
  end
end

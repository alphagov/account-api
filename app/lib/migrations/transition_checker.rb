# frozen_string_literal: true

module Migrations
  class TransitionChecker
    LOCAL_ATTRIBUTE_NAME = "transition_checker_state"
    EMAIL_SUBSCRIPTION_NAME = "transition-checker-results"

    def self.call(token)
      new(token).migrate!
    end

    def initialize(token)
      @token = token
      @uri = "#{Plek.find('account-manager')}/api/v1/migrate-users-to-account-api"
    end

    def migrate!
      page = 0
      is_last_page = false
      until is_last_page
        response = HTTParty.get("#{uri}?page=#{page}", headers: { "Accept" => "application/json", "Authorization" => "Bearer #{token}" })
        response["users"].each { |user| migrate_user! user }
        is_last_page = response["is_last_page"]
        page += 1
      end
    end

  private

    attr_reader :uri, :token

    def migrate_user!(user_record)
      User.transaction do
        oidc_user = OidcUser.find_or_create_by!(sub: user_record["subject_identifier"])

        LocalAttribute
          .create_with(
            value: user_record["transition_checker_state"],
          )
          .find_or_create_by!(
            oidc_user_id: oidc_user.id,
            name: LOCAL_ATTRIBUTE_NAME,
          )

        EmailSubscription
          .create_with(
            topic_slug: user_record["topic_slug"],
            email_alert_api_subscription_id: user_record["email_alert_api_subscription_id"],
          )
          .find_or_create_by!(
            oidc_user_id: oidc_user.id,
            name: EMAIL_SUBSCRIPTION_NAME,
          )
      end
    end
  end
end

class UserController < ApplicationController
  include AuthenticatedApiConcern

  HOMEPAGE_ATTRIBUTES = %i[email email_verified transition_checker_state].freeze

  def show
    render_api_response(
      {
        level_of_authentication: @govuk_account_session.level_of_authentication,
        email: attributes.dig(:email, :value),
        email_verified: attributes.dig(:email_verified, :value),
        services: {
          transition_checker: attribute_service(:transition_checker_state),
          saved_pages: saved_pages_service,
        }.compact,
      },
    )
  end

private

  def attribute_service(attribute_name)
    attributes[attribute_name][:state]
  end

  def saved_pages_service
    if @govuk_account_session.user.saved_pages.exists?
      :yes
    else
      :no
    end
  end

  def attributes
    @attributes ||=
      begin
        attribute_values = @govuk_account_session.get_attributes(HOMEPAGE_ATTRIBUTES.select { |name| has_permission_for name, :check }).symbolize_keys

        HOMEPAGE_ATTRIBUTES.index_with do |name|
          if attribute_values.key? name
            if has_permission_for name, :get
              { state: :yes, value: attribute_values[name] }
            else
              { state: :yes_but_must_reauthenticate }
            end
          elsif has_permission_for name, :check
            { state: :no }
          else
            { state: :unknown }
          end
        end
      end
  end

  def has_permission_for(attribute_name, permission_level)
    user_attributes.has_permission_for? attribute_name, permission_level, @govuk_account_session
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end

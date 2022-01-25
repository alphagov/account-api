class Internal::UserController < InternalController
  include AuthenticatedApiConcern

  HOMEPAGE_ATTRIBUTES = %w[email email_verified].freeze

  def show
    render_api_response(
      {
        id: @govuk_account_session.user.id.to_s,
        mfa: @govuk_account_session.mfa?,
        email: attributes.dig("email", :value),
        email_verified: attributes.dig("email_verified", :value),
        services: {},
      },
    )
  end

private

  def attributes
    @attributes ||=
      begin
        attribute_values = @govuk_account_session.get_attributes(HOMEPAGE_ATTRIBUTES.select { |name| has_permission_for name, :check })

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

ARG ruby_version=3.1.2
ARG base_image=ghcr.io/alphagov/govuk-ruby-base:$ruby_version
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:$ruby_version

FROM $builder_image AS builder

WORKDIR $APP_HOME
COPY Gemfile Gemfile.lock .ruby-version ./
# TODO: remove chmod workaround once https://www.github.com/mikel/mail/issues/1489 is fixed.
RUN bundle install && chmod -R o+r "${BUNDLE_PATH}"

COPY . ./

FROM $base_image

ENV GOVUK_APP_NAME=account-api

WORKDIR $APP_HOME
COPY --from=builder $BUNDLE_PATH/ $BUNDLE_PATH/
COPY --from=builder $APP_HOME ./

USER app
CMD ["puma"]

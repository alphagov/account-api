# Account API

Provides sign in / sign out and attribute storage functionality to
other GOV.UK applications.

In production this app currently uses the Digital Identity
authentication service.

This app does not serve any user-facing pages. To see the app working, you
must run an app which uses it, such as [Finder Frontend][].

After starting Finder Frontend, you should be able to access the
following links:

- the [Brexit checker journey start page][tc-start]
- the [Brexit checker results page][tc-results] that reflects the
  answers you give during the Brexit checker journey
- the [account sign up page][tc-save-results] to save your answers

[Finder Frontend]: https://github.com/alphagov/finder-frontend
[tc-results]: http://finder-frontend.dev.gov.uk/transition-check/results?c[]=living-ie
[tc-save-results]: http://finder-frontend.dev.gov.uk/transition-check/save-your-results?c%5B%5D=living-ie
[tc-start]: http://finder-frontend.dev.gov.uk/transition-check/questions


## Technical documentation

This is a Ruby on Rails app, and should follow [our Rails app
conventions][].

[our Rails app conventions]: https://docs.publishing.service.gov.uk/manual/conventions-for-rails-applications.html

Use GOV.UK Docker to run any of the following commands.

### Testing

This repository follows the standards for testing described in the
[GOV.UK RFC on continuous deployment][]:

- code coverage in excess of 95%
- API contract tests ("pact tests") between the Account API and its
  consumers
- a [smoke test][] to check the application is running after a
  deployment

The default `rake` task runs all the tests and records code coverage:

```sh
bundle exec rake
```

[GOV.UK RFC on continuous deployment]: https://github.com/alphagov/govuk-rfcs/blob/main/rfc-128-continuous-deployment.md
[smoke test]: https://github.com/alphagov/smokey/blob/main/features/account_api.feature

#### Changing the Pact tests

If you make changes to the API, you must update the Pact tests.

A Pact test has two parts:

1. The consumer test (defined [in gds-api-adapters][]), which:
   - specifies the state it expects the provider to be in
   - gives a request to make
   - and a response to match against

2. The provider configuration (defined [in this repo][]), which
   defines all of the provider states referenced by the consumer
   tests.

See the GOV.UK Developer Docs for [how to update a Pact test][].

[in this repo]: https://github.com/alphagov/account-api/blob/main/spec/service_consumers/pact_helper.rb
[in gds-api-adapters]: https://github.com/alphagov/gds-api-adapters/blob/master/test/account_api_test.rb
[how to update a Pact test]: https://docs.publishing.service.gov.uk/manual/pact-broker.html#updating-pact-tests


## Further documentation

- [API documentation](docs/api.md)


## Licence

[MIT License](LICENCE)

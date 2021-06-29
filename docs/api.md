# API documentation

This API is for GOV.UK Publishing microservices (the things which make
up www.gov.uk) to implement personalisation and user session
management. This API is not for other government services.

- [Nomenclature](#nomenclature)
  - [Identity provider](#identity-provider)
  - [Session identifier](#session-identifier)
- [Using this API](#using-this-api)
- [API endpoints](#api-endpoints)
  - [`GET /api/oauth2/sign-in`](#get-apioauth2sign-in)
  - [`POST /api/oauth2/callback`](#post-apioauth2callback)
  - [`POST /api/oauth2/state`](#post-apioauth2state)
  - [`GET /api/user`](#get-apiuser)
  - [`GET /api/attributes`](#get-apiattributes)
  - [`PATCH /api/attributes`](#patch-apiattributes)
  - [`GET /api/attributes/names`](#get-apiattributesnames)
  - [`GET /api/transition-checker-email-subscription`](#get-apitransition-checker-email-subscription)
  - [`POST /api/transition-checker-email-subscription`](#post-apitransition-checker-email-subscription)
  - [`GET /api/email-subscriptions/:subscription_name`](#get-apiemail-subscriptionssubscription_name)
  - [`PUT /api/email-subscriptions/:subscription_name`](#put-apiemail-subscriptionssubscription_name)
  - [`DELETE /api/email-subscriptions/:subscription_name`](#delete-apiemail-subscriptionssubscription_name)
  - [`GET /api/saved-pages`](#get-apisaved-pages)
  - [`GET /api/saved-pages/:page_path`](#get-apisaved-pagespage_path)
  - [`PUT /api/saved-pages/:page_path`](#put-apisaved-pagespage_path)
  - [`DELETE /api/saved-pages/:page_path`](#delete-apisaved-pagespage_path)
- [API errors](#api-errors)
  - [Level of authentication too low](#level-of-authentication-too-low)
  - [Unknown attribute names](#unknown-attribute-names)
  - [Unwritable attributes](#unwritable-attributes)
  - [Page cannot be saved](#page-cannot-be-saved)

## Nomenclature

### Identity provider

The service which authenticates a user. Currently we use the [GOV.UK account manager prototype][].

### Session identifier

An opaque token which identifies a user and provides access to their attributes.

[GOV.UK account manager prototype]: https://github.com/alphagov/govuk-account-manager-prototype/

## Using this API

You should use this API in combination with the [govuk_personalisation][] gem, like so:

```ruby
class YourRailsController < ApplicationController
  # include the concern in your controller
  include GovukPersonalisation::AccountConcern

  def show
    # call the API with gds-api-adapters, the @govuk_account_session is provided by the concern
    result = GdsApi.account_api.get_attributes(
      attributes: %w[some user attributes],
      govuk_account_session: @govuk_account_session,
    )

    # set up the response header and update @govuk_account_session
    set_account_session_header(result["govuk_account_session"])

    # do something in your view with the result
    @attributes = result["values"]
  rescue GdsApi::HTTPUnauthorized
    # the user's session is invalid
    logout!
  rescue GdsApi::HTTPForbidden
    # the user needs to reauthenticate, the required level of authentication is in the response body
  end
end
```

The [govuk_personalisation][] gem handles setting the `GOVUK-Account-Session` and `Vary` response headers for your app, ensuring that responses are not cached.  In local development there is a cookie instead of a custom header, which the gem also handles for you.

[govuk_personalisation]: https://github.com/alphagov/govuk_personalisation

## API endpoints

### `GET /api/oauth2/sign-in`

Generates an OAuth sign in URL.

This URL should be served to the user with a 302 response to authenticate the user against the identity provider.

#### Query parameters

- `level_of_authentication` *(optional)*
  - either `level1` (require MFA) or `level0` (do not require MFA, the default)
- `state_id` *(optional)*
  - an identifier returned from a previous call to `POST /api/oauth2/state`
- `redirect_path` *(optional)*
  - a path on GOV.UK to send the user to after authenticating

#### JSON response fields

- `auth_uri`
  - an absolute URL, pointing to the identity provider, which the user should be redirected to so they can authenticate
- `state`
  - a random string, used for CSRF protection, which should be stored in a cookie and compared with the `state` returned by the identity provider after the user authenticated

#### Response codes

- 200

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_sign_in_url(
    redirect_path: "/guidance/keeping-a-pet-pig-or-micropig",
    state_id: "12345",
)
```

Response:

```json
{
    "auth_uri": "https://www.account.publishing.service.gov.uk/oauth/authorize?client_id=clientid&nonce=nonce&redirect_uri=https%3A%2F%2Fwww.gov.uk%2Fsign-in%2Fcallback&response_type=code&scope=openid&state=12345%3Aabcd",
    "state": "12345:abcdef"
}
```

### `POST /api/oauth2/callback`

Validates an OAuth response from the identity provider.

On a `401: Unauthorized` response, the identity provider has rejected the authentication parameters.

#### Request parameters

- `code`
  - the value of the `code` parameter returned from the identity provider
- `state`
  - the value of the `state` parameter returned from the identity provider

#### JSON response fields

- `govuk_account_session`
  - a session identifier
- `redirect_path` *(optional)*
  - the `redirect_path` which was previously passed to `GET /api/oauth2/sign-in`, if given
- `ga_client_id` *(optional)*
  - the Google Analytics client ID which the identity provider used for analytics

#### Response codes

- 401 if authentication is unsuccessful
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.validate_auth_response(
    code: "12345",
    state: "67890",
)
```

Response:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "redirect_path": "/guidance/keeping-a-pet-pig-or-micropig",
    "ga_client_id": "ga-123-userid"
}
```

### `POST /api/oauth2/state`

Stores some initial attributes which will be persisted if a user creates an account rather than logging in.

#### JSON request parameters

- `attributes`
  - a JSON object where keys are attribute names and values are attribute values

#### JSON response fields

- `state_id`
  - an identifier to pass to `GET /api/oauth2/sign-in`

#### Response codes

- 200

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.create_registration_state(
    attributes: { name1: "value1", name2: "value2" },
)
```

Response:

```json
{
    "state_id": "5821a9f9-3ba7-4385-a864-80cdb374550a"
}
```

### `GET /api/user`

Retrieves the information needed to render the `/account/home` page.

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### JSON response fields

- `id`
  - the user identifier
- `level_of_authentication`
  - the user's current level of authentication (`level0` or `level1`)
- `email`
  - the user's current email address
- `email_verified`
  - whether the user has confirmed their email address or not
- `services`
  - object of known services, keys are service names and values are one of:
    - `yes`: the user has used the service and can use it now
    - `yes_but_must_reauthenticate`: the user has used the service but must reauthenticate at a higher level to use it now
    - `no`: the user has not used the service
    - `unknown`: the user is not authenticated at a high enough level to check whether they have used the service or not

#### Response codes

- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_user(
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "level_of_authentication": "level0",
    "email": "email@example.com",
    "email_verified": false,
    "services": {
        "transition_checker": "yes_but_must_reauthenticate",
        "saved_pages": "yes"
    }
}
```

### `GET /api/attributes`

Retrieves attribute values for the current user.

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Query parameters

- `attributes[]` *(one for each attribute)*
  - a list of attribute names, specified once for each name

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `values`
  - a JSON object of attribute values, where keys are attribute names and values are attribute values

#### Response codes

- 422 if any attributes are unknown (see [error: unknown attribute names](#unknown-attribute-names))
- 403 if the session's level of authentication is too low (see [error: level of authentication too low](#level-of-authentication-too-low))
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_attributes(
    attributes: %w[name1 name2],
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "values": {
        "name1": "value1",
        "name2": "value2"
    }
}
```

### `PATCH /api/attributes`

Updates the attributes of the current user.

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### JSON request parameters

- `attributes`
  - a JSON object where keys are attribute names and values are attribute values

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier

#### Response codes

- 422 if any attributes are unknown (see [error: unknown attribute names](#unknown-attribute-names))
- 403 if any attributes are unwritable (see [error: unwritable attributes](#unwritable-attributes))
- 403 if the session's level of authentication is too low (see [error: level of authentication too low](#level-of-authentication-too-low))
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.set_attributes(
    attributes: { name1: "value1", name2: "value2" },
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg=="
}
```

### `GET /api/attributes/names`

Retrieves attribute names for the current user.

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Query parameters

- `attributes[]` *(one for each attribute)*
  - a list of attribute names, specified once for each name

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `values`
  - a JSON array of attribute names

#### Response codes

- 422 if any attributes are unknown (see [error: unknown attribute names](#unknown-attribute-names))
- 403 if the session's level of authentication is too low (see [error: level of authentication too low](#level-of-authentication-too-low))
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_attributes(
    attributes: %w[name1 name2],
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "values": ["name1", "name2"]
}
```

### `GET /api/transition-checker-email-subscription`

Checks if the user has an active Transition Checker email subscription.

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `has_subscription`
  - a boolean

#### Response codes

- 403 if the session's level of authentication is too low (see [error: level of authentication too low](#level-of-authentication-too-low))
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.check_for_email_subscription(
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "has_subscription": false
}
```

### `POST /api/transition-checker-email-subscription`

Updates the user's Transition Checker email subscription, cancelling any previous subscription they had.

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `slug`
  - the email topic slug to subscribe to

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier


#### Response codes

- 403 if the session's level of authentication is too low (see [error: level of authentication too low](#level-of-authentication-too-low))
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.set_email_subscription(
    govuk_account_session: "session-identifier",
    slug: "slug-name",
)
```

Response:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg=="
}
```

### `GET /api/email-subscriptions/:subscription_name`

Get the details of a named email subscription

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `subscription_name`
  - the name of the subscription

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `email_subscription`
  - details of the subscription

#### Response codes

- 404 if there is no such subscription (or if it has been deleted)
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_email_subscription(
    name: "transition-checker",
    govuk_account_session: "session-identifier",
)
```

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "email_subscription": {
      "name": "transition-checker",
      "topic_slug": "brexit-results-12345",
      "email_alert_api_subscription_id": "cd5f6972-faf3-4f1c-bb76-3774b0a389f0"
    },
}
```

### `PUT /api/email-subscriptions/:subscription_name`

Create or update a named email subscription

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `subscription_name`
  - the name of the subscription

#### JSON request parameters

- `topic_slug`
  - the email-alert-api topic slug

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `email_subscription`
  - details of the subscription

#### Response codes

- 422 if the `topic_slug` parameter is missing
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.put_email_subscription(
    name: "transition-checker",
    topic_slug: "brexit-results-12345",
    govuk_account_session: "session-identifier",
)
```

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "email_subscription": {
      "name": "transition-checker",
      "topic_slug": "brexit-results-12345",
      "email_alert_api_subscription_id": "96ae61d6-c2a1-48cb-8e67-da9d105ae381"
    },
}
```

### `DELETE /api/email-subscriptions/:subscription_name`

Cancel and remove a named email subscription

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `subscription_name`
  - the name of the subscription

#### Response codes

- 404 if there is no such subscription (or if it has been deleted)
- 401 if the session identifier is invalid
- 204 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.delete_email_subscription(
    name: "transition-checker",
    govuk_account_session: "session-identifier",
)
```

Response is status code only.

### `GET /api/saved-pages`

Returns all a user's saved pages

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `saved_pages`
  - an array of pages the user has saved, identified by their page path

#### Response codes

- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_saved_pages(
    govuk_account_session: "session-identifier",
)
```

Response when no pages are saved:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "saved_pages": []
}
```

Response when a user has saved two pages:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "saved_pages": [
      {
        "page_path": "/government/organisations/government-digital-service",
        "content_id": "af07d5a5-df63-4ddc-9383-6a666845ebe9",
        "title": "Government Digital Service"
      },
      {
        "page_path": "/government/organisations/cabinet-office",
        "content_id": "96ae61d6-c2a1-48cb-8e67-da9d105ae381",
        "title": "Cabinet Office"
      },
  ]
}
```

### `GET /api/saved-pages/:page_path`

Query if a specific path has been saved by the user

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `page_path`
  - the path on GOV.UK to save

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `saved_page`
  - an object containing the page path of the successfully queried page

#### Response codes

- 404 cannot find a page with the provided path
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_saved_page(
    page_path: "/guidance/bar",
    govuk_account_session: "session-identifier",
)
```

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "saved_page": {
      "page_path": "/guidance/bar",
      "content_id": "96ae61d6-c2a1-48cb-8e67-da9d105ae381",
      "title": "Guidance for Bar-related Activities"
    },
}
```

### `PUT /api/saved-pages/:page_path`

Upsert a saved page in a user's account

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `page_path`
  - An escaped URL safe string that identifies the path of a saved page.

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `saved_page`
  - an object containing the page path of the successfully saved page

#### Response codes

- 422 if the page could not be saved (see [error: page cannot be saved](#page-cannot-be-saved))
- 410 if the page has been removed (the latest edition is in the "gone" or "redirect" state)
- 404 if the page does not exist (not present in the content store)
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.save_page(
    page_path: "/guidance/foo",
    govuk_account_session: "session-identifier",
)
```

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "saved_page": {
      "page_path": "/guidance/foo",
      "content_id": "96ae61d6-c2a1-48cb-8e67-da9d105ae381",
      "title": "Guidance for Foo-related Activities"
    },
}
```

### `DELETE /api/saved-pages/:page_path`

Remove a saved page from a user's account

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `page_path`
  - the path on GOV.UK to save

#### Response codes

- 404 cannot find a page with the provided path
- 401 if the session identifier is invalid
- 204 successfully deleted

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.delete_saved_page(
    page_path: "/guidance/bar",
    govuk_account_session: "session-identifier",
)
```

Response is status code only.

## API errors

API errors are returned as an [RFC 7807][] "Problem Detail" object, in
the following format:

```json
{
  "type": "URI which identifies the problem type and points to further information",
  "title": "Short human-readable summary of the problem type",
  "detail": "Human-readable explanation of this specific instance of the problem."
}
```

Each error type may define additional response fields.

[RFC 7807]: https://tools.ietf.org/html/rfc7807

### Level of authentication too low

You have tried to access something which the current user is not
authenticated highly enough to use.  The
`needed_level_of_authentication` response field gives the required
level.

#### Debugging steps

This is not an error, the user must be reauthenticated at the higher
level to access.

### Unknown attribute names

One or more of the attribute names you have specified are not known.
The `attributes` response field lists these.

### Unwritable attributes

One or more of the attributes you have specified cannot be updated
through account-api.  The `attributes` response field lists these.

Do not just reauthenticate the user and try again.

### Page cannot be saved

The page you have specified could not be saved. The errors response field lists the problems.

#### Debugging steps

- check the `errors` returned as an extra detail in the response for specific error messages

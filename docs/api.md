# API documentation

This API is for GOV.UK Publishing microservices (the things which make
up www.gov.uk) to implement personalisation and user session
management. This API is not for other government services.

- [Nomenclature](#nomenclature)
  - [Identity provider](#identity-provider)
  - [Session identifier](#session-identifier)
- [Requirements for API consumers](#requirements-for-api-consumers)
  - [Request custom headers](#request-custom-headers)
  - [Response custom headers](#response-custom-headers)
  - [Update the user's session if a new session identifier is returned](#update-the-users-session-if-a-new-session-identifier-is-returned)
  - [End the user's session if an endpoint returns a `401: Unauthenticated`](#end-the-users-session-if-an-endpoint-returns-a-401-unauthenticated)
  - [Ensure responses are not cached](#ensure-responses-are-not-cached)
- [Example API usage](#example-api-usage)
- [API endpoints](#api-endpoints)
  - [`GET /api/oauth2/sign-in`](#get-apioauth2sign-in)
  - [`POST /api/oauth2/callback`](#post-apioauth2callback)
  - [`POST /api/oauth2/state`](#post-apioauth2state)
  - [`GET /api/attributes`](#get-apiattributes)
  - [`PATCH /api/attributes`](#patch-apiattributes)
  - [`GET /api/attributes/names`](#get-apiattributesnames)
  - [`GET /api/transition-checker-email-subscription`](#get-apitransition-checker-email-subscription)
  - [`POST /api/transition-checker-email-subscription`](#post-apitransition-checker-email-subscription)
- [API errors](#api-errors)
  - [Level of authentication too low](#level-of-authentication-too-low)
  - [Unknown attribute names](#unknown-attribute-names)

## Nomenclature

### Identity provider

The service which authenticates a user. Currently we use the [GOV.UK account manager prototype][].

### Session identifier

An opaque token which identifies a user and provides access to their attributes.

[GOV.UK account manager prototype]: https://github.com/alphagov/govuk-account-manager-prototype/

## Requirements for API consumers

We manage user sessions in frontend apps by using custom headers, which tie into logic in our Content Delivery Network (CDN). This section describes what you have to do to manage those custom headers correctly.

### Request custom headers

The request custom header is `GOVUK-Account-Session`.

This custom header is set by our CDN to the value of the user's session cookie. This is the user's session identifier.

See the [`govuk-cdn-config` VCL](https://github.com/alphagov/govuk-cdn-config/blob/2ade45759be947a28b1225aee085311430bcbecf/vcl_templates/www.vcl.erb#L339-L340) for more information.

### Response custom headers

The response custom headers are:

- `GOVUK-Account-Session`
- `GOVUK-Account-End-Session`

`GOVUK-Account-Session` is sent to our CDN to update the user's session cookie.

`GOVUK-Account-End-Session` is sent to our CDN to delete the user's session cookie.

See the [`govuk-cdn-config` VCL](https://github.com/alphagov/govuk-cdn-config/blob/2ade45759be947a28b1225aee085311430bcbecf/vcl_templates/www.vcl.erb#L442-L455) for more information.

We do not have a CDN when developing locally. To enable local development with Accounts, we store the session identifier
in a cookie called `govuk_account_session`, with `domain: dev.gov.uk`, when running in development mode.

We may later provide a gem implementing this behaviour.

### Update the user's session if a new session identifier is returned

Some of these endpoints return a session identifier in the `govuk_account_session` JSON response field. If this happens, you must update the user's session identifier.

1. Set the `GOVUK-Account-Session` response custom header:

    ```ruby
    response.headers["GOVUK-Account-Session"] = "<govuk_account_session value>"
    ```

1. Update the development cookie when running locally:

    ```ruby
    if Rails.env.development?
      cookies["govuk_account_session"] = {
        value: "<govuk_account_session value>",
        domain: "dev.gov.uk",
      }
    end
    ```

### End the user's session if an endpoint returns a `401: Unauthenticated`

If an endpoint returns a `401: Unauthenticated` response, then the user must no longer be considered logged in.

1. Set the `GOVUK-Account-End-Session` response header:

    ```ruby
    response.headers["GOVUK-Account-End-Session"] = "1"
    ```

1. Expire the development cookie when running locally:

    ```ruby
    if Rails.env.development?
      cookies["govuk_account_session"] = {
        value: "",
        domain: "dev.gov.uk",
        expires: 1.second.ago,
      }
    end
    ```

### Ensure responses are not cached

Any user-visible response which involves calling this API must return appropriate response headers to either forbid caching, or specific that the response depends on the user.

To forbid caching:

```ruby
response.headers["Cache-Control"] = "no-store"
```

To specify that the response depends on the user:

```ruby
response.headers["Vary"] = [response.headers["Vary"], "GOVUK-Account-Session"].compact.join(", ")
```

## Example API usage

This is an example of updating an attribute for the current user.

The `update` method is the controller action.  The `disable_cache`,
`fetch_session_identifier`, `set_session_identifier`, and `logout!`
methods would be re-used by other actions which call this API.

```ruby
before_action :disable_cache, only: %i[update]
before_action :fetch_session_identifier, only: %i[update]

def update
  head :unauthorised and return unless @session_identifier

  api_response = GdsApi.account_api.set_attributes(
    govuk_account_session: @session_identifier,
    attributes: { example_attribute: params[:attribute_value] },
  ).to_h

  set_session_identifier api_response["govuk_account_session"]
rescue GdsApi::HTTPUnauthorized
  logout!
  render plain: "you have been logged out"
end

private

def disable_cache
  response.headers["Cache-Control"] = "no-store"
end

def fetch_session_identifier
  @session_identifier =
    if request.headers["HTTP_GOVUK_ACCOUNT_SESSION"]
      request.headers["HTTP_GOVUK_ACCOUNT_SESSION"]
    elsif Rails.env.development?
      cookies["govuk_account_session"]
    end
end

def set_session_identifier(session_identifier)
  return unless session_identifier

  response.headers["GOVUK-Account-Session"] = @session_identifier

  if Rails.env.development?
    cookies["govuk_account_session"] = {
      value: @session_identifier,
      domain: "dev.gov.uk",
    }
  end
end

def logout!
  @session_identifier = nil

  response.headers["GOVUK-Account-End-Session"] = "1"

  if Rails.env.development?
    cookies["govuk_account_session"] = {
      value: "",
      domain: "dev.gov.uk",
      expires: 1.second.ago,
    }
  end
end
```


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

#### Debugging steps

- check that you don't have a typo in the attribute names
- check that the attributes are defined in `config/user_attributes.yml`
- check that you are running the latest version of account-api

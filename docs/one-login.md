# Digital Identity

This document gets into some of the details of the integration with
Digital Identity, and where it can go wrong.  For a high-level
overview, see [the developer docs][].

[the developer docs]: https://docs.publishing.service.gov.uk/manual/govuk-account.html

## Big picture

The [`OidcUser` model][], which represents a user who has
authenticated via Digital Identity, holds four special pieces of data:

- The `sub`, or "subject identifier", is a unique identifier assigned
  by Digital Identity when the account is created, and never changes.
  Other data, like an email address, can change: so this is what we
  use to identify users.

- The `legacy_sub` is the user's subject identifier from the old
  [account manager prototype][].  Only accounts which were created
  before the Digital Identity migration have this set.  We use this to
  join up old data.

- The `email` is the user's current email address.  It is set by
  Digital Identity calling the `/api/oidc-users/:subject_identifier`
  endpoint.

- The `email_verified` is a boolean denoting whether the user's email
  address is verified.  It is set by Digital Identity calling the
  `/api/oidc-users/:subject_identifier` endpoint.  As Digital Identity
  require immediate verification of email addresses, this is always
  true.

Communication flows in both directions between account-api and Digital
Identity:

- When a user is updated or deleted, Digital Identity call the
  endpoints in [`Internal::OidcUsersController`][].

- When a user logs in, we call Digital Identity from the
  [`Internal::AuthenticationController`][].

[`OidcUser` model]: https://github.com/alphagov/account-api/blob/main/app/models/oidc_user.rb
[`Internal::OidcUsersController`]: https://github.com/alphagov/account-api/blob/main/app/controllers/internal/oidc_users_controller.rb
[`Internal::AuthenticationController`]: https://github.com/alphagov/account-api/blob/main/app/controllers/internal/authentication_controller.rb
[account manager prototype]: https://github.com/alphagov/govuk-account-manager-prototype/

## Errors

This is a non-exhaustive list of problems that could be due to
something breaking with the Digital Identity integration.

Firstly, check if the problem is on the Digital Identity side:

- If the user got the problem on `https://account.gov.uk` (or some
  subdomain of that), then it's Digital Identity.
- If account-api is persistently unable to connect to
  `https://oidc.account.gov.uk`, then it's Digital Identity.

If the problem is on the Digital Identity side, or if you need support
from them, ask for help in `#di-authentication` on Slack.

If the problem is not clearly to do with Digital Identity, read on.

### Email address out of date

Find out from the user what the email address should be and what it's
currently showing as.

You can find their user record with:

```ruby
user = OidcUser.find_by(email: "currently showing address")
```

You can also see if there is a user with the email address they are
trying to change to:

```ruby
other_user = OidcUser.find_by(email: "desired new email address")
```

Digital Identity enforces that email addresses are unique, so we
shouldn't ever have two users with the same email address.

If there is another user with the desired email address, something may
have gone wrong with updating *their* user record, which will have to
be resolved before this user can be updated.

#### Check Sentry for `CapturedSensitiveException` events

<a name="captured-sensitive-exception"></a>

See the account-api [Sentry project][].

A `CapturedSensitiveException` means that an exception has been raised
in some code which deals with email addresses.  To avoid leaking PII,
we save the real exception details to the database as a
`SensitiveException` model, and report to Sentry:

- `id`, the subject identifier of the `OidcUser` involved.
- `sensitive_exception_id`, the database identifier of the `SensitiveException`.

Get the message of any new `CapturedSensitiveException`s in Sentry and
see if any of them are relevant to the email addresses in question.

If there problem is that there is a clash with another user, then you
may have to follow a chain of exceptions to get to the real root
cause.  A clash will have an error like:

```
ActiveRecord::RecordNotUnique: PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_oidc_users_on_email"
DETAIL:  Key (email)=(email@example.com) already exists.
```

[Sentry project]: https://sentry.io/organizations/govuk/issues/?project=5671868

#### There is no relevant error

If a user has the wrong email address and there is no relevant error,
then Digital Identity may not have called the
`/api/oidc-users/:subject_identifier` endpoint, or their call may have
failed due to some error which wasn't reported.

Check Kibana to see if the call was made and what the response code
was.  If the call wasn't made at all, contact Digital Identity for
support.

### Can't log in

Find out from the user what the email address they've used for their
account is.

You can find their user record with:

```ruby
user = OidcUser.find_by(email: "address")
```

#### Can't log in for the first time

When a user first logs in, we create an `OidcUser` record just holding
their subject identifier, and query Digital Identity for their email
address.

So if there is no `OidcUser` record with the email address, this
process may have failed.

##### Check Sentry for `ActiveRecord::RecordNotUnique` events

An exception is raised if two `OidcUsers` have the same subject
identifier:

```
ActiveRecord::RecordNotUnique: PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_oidc_users_on_sub"`
DETAIL:  Key (sub)=(foo) already exists.
```

This should never happen in production.

As subject identifiers come from Digital Identity, contact them for
support and give the duplicate subject identifier (`foo` in the
example above).

##### Check Sentry for `CapturedSensitiveException` events

Try the [debugging steps](#captured-sensitive-exception) described
earlier (under "email address out of date"): if there is another user
record with the user's email address, creating their account will
fail.

##### Check Sentry for `UserDestroyed` events

An exception is raised if a user logs into an account which Digital
Identity has previously told us is deleted:

```
AccountSession::UserDestroyed (AccountSession::UserDestroyed):

app/lib/account_session.rb:27:in `initialize'
app/controllers/internal/authentication_controller.rb:22:in `new'
app/controllers/internal/authentication_controller.rb:22:in `callback'
```

This is because we create a `Tombstone` record when a user is
destroyed.  This record holds the subject identifier, and we use it to
end any active sessions that user still has.

If a user logs into an account that has a subject identifier with a
corresponding `Tombstone` record, Digital Identity have re-used a
subject identifier, or un-deleted the account.  We currently assume
this does not happen.

Removing the `Tombstone` record will allow the user to log in.  But if
this is an account which has been un-deleted, any data we held on them
will be lost.

#### Can't log in at other times

Ask the `#di-authentication` channel in Slack whether their service is
up, and ask if they are seeing an elevated rate of invalid
authorization codes or access tokens from GOV.UK.

If Digital Identity are experiencing a problem, we just have to wait
for them to fix it.

Otherwise, we have a bug in account-api, or perhaps elsewhere in the
GOV.UK stack.  One thing to try would be to clear our cached copy of
the Digital Identity OIDC configuration:

```ruby
Rails.cache.clear
```

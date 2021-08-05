Flash messages
==============

[The flash][] is a special piece of per-request state in the Rails
session:

```ruby
flash[:notice] = "message"
```

Makes a `:notice` flash which is available to the next request:

```ruby
<h1><%= flash[:notice] %></h1>
```

And then is cleared.

This is useful for showing success or failure messages, or other
confirmation-style notices.

[The flash]: https://guides.rubyonrails.org/action_controller_overview.html#the-flash


Flash messages and microservices
--------------------------------

Since flash messages are in the Rails session, they cannot be used
across microservices (without sharing the session encryption key).
But that is a feature we would like.

For example, consider the user journey for email notifications:

1. Click "Sign up for notifications" link on the page
2. Sign in
3. [in the background] The subscription is created and the user redirected back to the original page

After step 3, the user doesn't get any immediate feedback that they
now have signed up.  This is where a flash message would be useful.


Storing flash messages in the GOV.UK account session
----------------------------------------------------

The current format of the account session is:

```ruby
base64("#{salt}$$#{encrypt(session_hash)}")
```

Flash messages could be stored in the `session_hash`, but then apps
would need to call account-api to get or set them, as the encryption
key is not shared.

So instead, let's store flash messages as plaintext:

```ruby
base64("#{salt}$$#{encrypt(session_hash)}") + "$$#{flash_messages.join(',')}"
```

To avoid decoding issues, the messages must be URL-safe and cannot
contain a `"$$"` or a `","`.  For security, also don't want to store
any sensitive data in plaintext.  So we will instead store message
identifiers (like `email_subscription_created`) rather than messages
themselves (like `Success, you have signed up to Super Sensitive
Topic!`).

We can enforce this by putting the flash message manipulation logic in
[govuk_personalisation][] and mandating that they use a restricted
character set (*e.g.* `[a-zA-Z0-9_-\.]+`).

The following will be added to the `GovukPersonalisation::AccountConcern`:

```ruby
attr_reader :account_flash      # an array of messages

def account_flash_add(value)    # add a value to the flash

def account_flash_keep          # keep the entire flash for the next request
```

The `fetch_account_session_header` method will be changed to set
`@account_flash`.

The response headers will be changed to:

```ruby
response.headers[ACCOUNT_SESSION_HEADER_NAME] = "#{@account_session_header}$$#{@new_account_flash.join(',')}"
```

Where `@new_account_flash` is an initially-empty array.  This is
because flash messages do not persist between requests.  If an app
needs to persist some flash messages, it can use `account_flash_add`
or `account_flash_keep` to set the necessary ones.

[govuk_personalisation]: https://github.com/alphagov/govuk_personalisation


Will account-api itself use flash messages?
-------------------------------------------

In `AccountSession.deserialise` we will drop any flash messages.

They do not (yet) affect the functioning of account-api.  If, in the
future, we want to communicate flash messages from account-api to
other GOV.UK microservices, we can revisit this.

Flash messages are entirely a concern for [govuk_personalisation][]
and frontend apps.


An example usage
----------------

Returning to the example of signing up for email notifications, flash
messages would let us do this:

1. Click "Sign up for notifications" link on the page
2. Sign in
3. [in the background] The subscription is created, a success flash message is set, and the user redirected back to the original page
4. See a "success" banner on the page

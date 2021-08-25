Progressive enhancement
=======================

We think that there are three sorts of account related functionality
on GOV.UK:

1. **The Skeleton Account:** the core mechanics of signing in,
   registering, account management, navigating to services, and so on.

2. **Navigation:** some content will adjust based on whether the user
   is logged in or not.  For example the global header navigation
   needs to give the user the appropriate links to sign in or to sign
   out.

3. **Personalisation:** some content will adjust based on what we know
   about the user.  For example, telling the user that some content is
   not relevant to them, or showing an email notifications sign up
   button in a different state if the user has already signed up.

Arguably, Navigation is part of the Skeleton Account.  But they have
slightly different implications on implementation (one uses user data,
the other does not), so I'll discuss them separately.

The summary of this ADR is that **we have decided Personalisation will
be done, at least initially, in the frontend, with JavaScript, as a
form of progressive enhancement.**

The rest of this ADR explains why.

What's the Skeleton Account?
----------------------------

This is the core value proposition of the GOV.UK account: joining up
services and providing one place where a user can see their activity
and manage their settings and data.

If we don't have this, we have failed in our mission.

So far the Skeleton Account is implemented across the [account
manager][], running on the PaaS, and [frontend][].  We're bringing
[email-alert-frontend][] into the fold and, later on, the account
manager will go away and those parts of the Skeleton Account will be
replaced by a Digital Identity service.

The www.gov.uk parts of the Skeleton Account live under
`https://www.gov.uk/account/`.

**Implications on implementation:**

- This is critical functionality, so it has to work for all users.

- This is personalised.  Pages will show users their data, let users
  manage that data, show the user's activity, and so on.  So requests
  have to come through to our origin servers, which is where the data
  lives.

- This is non-cacheable.  Because it's personalised, at best we can
  cache one copy per user.  But we might not even want to do that,
  because there's a risk of a user seeing slightly out-of-date data.

[account manager]: https://github.com/alphagov/govuk-account-manager-prototype/
[frontend]: https://github.com/alphagov/frontend
[email-alert-frontend]: https://github.com/alphagov/email-alert-frontend/

What's Navigation?
------------------

This is likely just going to be the global navigation bar, which we
want to show in one of two states based on whether the user is logged
in or not.  I'm not sure where else we only care that the user is
logged in, and not who they are.

We currently show account navigation:

- On the Brexit landing page
- In the Brexit checker
- In the Skeleton Account pages

But the way we do this right now is by caching based on user ID.  This
is not good, as it means that a request for a new user is sent to our
origin servers, even though (since there is no user-specific
information here) we could serve a cached copy which had been served
to a different user.

**Implications on implementation:**

- This is also critical functionality, so it has to work for all
  users.  We've seen in user research how lost people are without a
  "Sign In" link in the header.

- This is *not* personalised.  All the logged in users will see the
  same navigation.  All the logged out users will see the same
  navigation.

- This is cacheable.  If a page only has navigation, and nothing
  personalised, it's perfectly safe to cache two copies of that page:
  one for logged in users, one for logged out users.

What's Personalisation?
-----------------------

This is the nice-to-have of the GOV.UK account.  If the Skeleton
Account is the cross-gov part of accounts, this is the GOV.UK-specific
part.  Personalisation features could be things like:

- Changing the state of a button to sign up for notifications based on
  whether the user has already done so.

- Displaying a message saying that this content is not relevant to the
  user based on what we know about them.

- Pre-selecting a tab on the Bank Holidays page based on knowing the
  user's location.

Unlike the Skeleton Account, Personalisation may end up touching
almost every page on GOV.UK.

**Implications on implementation:**

- This is *not* critical functionality.  It is an addition to the core
  value proposition of the GOV.UK account, but this by itself would
  not justify a GOV.UK account, and it wouldn't be a big loss to have
  the cross-gov part but not this.

- Like the Skeleton Account, this is personalised.  Pages are adjusted
  based on what we know about the current user.  So requests have to
  come through to our origin servers, which is where the data lives.

- Like the Skeleton Account, this is non-cacheable.  We could cache
  per-user, but might not want to because there is a risk of showing
  stale data.

Decisions
---------

We will use server-side rendering for the Skeleton Account pages and
for the Navigation.  We will treat Personalisation as a progressive
enhancement and do it client-side with JavaScript.

The upside is that we delay needing to change GOV.UK's architecture
for a world where almost nothing is cached.  That will be a difficult
task and take a while.  Iterating things will likely be quicker if
they're done in the frontend.

The downside is that we will have two versions of GOV.UK: one with
personalisation (which JavaScript users see) and one without.  Almost
all users have JavaScript enabled, but we still need to make sure the
non-JavaScript version works, and we will have to deal with a "flash
of unpersonalised content" - where users briefly see the generic page
before a personalised part loads.

### Improving caching for Navigation

To get the nice one-copy-for-all-logged-in-users caching behaviour for
Navigation, we'll need to add a new custom request header:

[In `vcl_recv`](https://github.com/alphagov/govuk-cdn-config/blob/8fd27e2a555f6fcb3edbd9d326210e53dbc2c66b/vcl_templates/www.vcl.erb#L368-L371):

```vcl
  # RFC 134
  if (req.http.Cookie ~ "__Host-govuk_account_session") {
    set req.http.GOVUK-Account-Session = req.http.Cookie:__Host-govuk_account_session;
    set req.http.GOVUK-Account-Session-Exists = "1";
  }
```

[In `vcl_deliver`](https://github.com/alphagov/govuk-cdn-config/blob/8fd27e2a555f6fcb3edbd9d326210e53dbc2c66b/vcl_templates/www.vcl.erb#L523-L537):

```vcl
  # RFC 134
  if (resp.http.GOVUK-Account-End-Session) {
    add resp.http.Set-Cookie = "__Host-govuk_account_session=; secure; httponly; samesite=lax; path=/; max-age=0";
  } else if (resp.http.GOVUK-Account-Session) {
    add resp.http.Set-Cookie = "__Host-govuk_account_session=" + resp.http.GOVUK-Account-Session + "; secure; httponly; samesite=lax; path=/";
  }

  if (resp.http.Vary ~ "GOVUK-Account-Session") {
    set resp.http.Vary:Cookie = "";
    set resp.http.Cache-Control:private = "";
  } else if (resp.http.Vary ~ "GOVUK-Account-Session-Exists") {
    set resp.http.Vary:Cookie = "";
    set resp.http.Cache-Control:private = "";
  }

  unset resp.http.GOVUK-Account-Session;
  unset resp.http.GOVUK-Account-End-Session;
  unset resp.http.Vary:GOVUK-Account-Session;
  unset resp.http.Vary:GOVUK-Account-Session-Exists;
```

Unfortunately, this means we will need navigation-selection logic in
every frontend app, which will be something like:

```ruby
  before_action do
    logged_in = request.headers["HTTP_GOVUK_ACCOUNT_SESSION_EXISTS"].present?
    set_slimmer_headers(remove_search: true, show_accounts: logged_in ? "signed-in" : "signed-out")
    response.headers["Vary"] = [response.headers["Vary"], "GOVUK-Account-Session-Exists"].compact.join(", ")
  end
```

But this can be added to [the `ControllerConcern` in govuk_personalisation][].

[the `ControllerConcern` in govuk_personalisation]: https://github.com/alphagov/govuk_personalisation/blob/main/lib/govuk_personalisation/controller_concern.rb

### Progressively enhancing Navigation

Even though every user gets the same Navigation HTML we can still
personalise it with progressive enhancement.  For example, say we want
to list a user's most visited pages in the header so they can get to
them quickly.  We'd do this like so:

1. The logged in header just has a link going to a page which lists
   their top pages.
2. JavaScript queries an API to fetch the top pages, and replaces the
   link in the header with this list.

Then users with JavaScript see their top pages, and users without
JavaScript get a link to go see them instead.

We will have to make sure that the unenhanced version of GOV.UK
(GOV.UK with just the Skeleton Account and Navigation) works.

### Dealing with the Flash of Unpersonalised Content

This is the main problem with the JavaScript approach.  Imagine if we
display a box at the top of a page telling the user that it's not
relevant to them, and it takes half a second for that box to appear
after the page has loaded: the content will move around and, if the
user has already started scrolling down, they may not see the box.

It's not a great user experience.  But we think the ease of
implementation is worth this cost.

Furthermore, as we demonstrate user value, we can begin to migrate
functionality out of JavaScript and into something like Compute@Edge
or Edge Side Includes.  It's better to be able to iterate on something
quickly and prove its value (even if with a less-than-ideal user
experience) before putting in the hard work to get it up to our usual
standards.

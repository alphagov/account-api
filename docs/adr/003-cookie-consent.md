Cookie consent
==============

We have decided to share cookie consent between www.gov.uk and the
Digital Identity domains.  This is so that if a user engages with the
cookie banner on one domain and then moves to the other, they don't
see a second banner: that would merely be annoying when clicking a
"sign in" link on www.gov.uk, but be downright confusing when clicking
the "security & privacy" link (which goes to a DI-owned domain) in the
account dashboard (which is on www.gov.uk).

We'll do this by decorating links which go between domains (including
buttons and redirects) with a `cookie_consent` parameter, which can
have three states:

- `accept`, if the user has accepted analytics cookies
- `reject`, if the user has rejected analytics cookies
- `not-engaged`, if the user has not engaged with the cookie banner

We already decorate such links, buttons, and redirects with a `_ga`
parameter, so that the cross-domain tracking works.  So we're now
adding a second parameter.

When a user arrives in either service, the client-side analytics
JavaScript checks the query param and updates its consent:

- `accept`: override any previous consent
- `reject`: override any previous consent
- `not-engaged`: use previous consent (if present), or show the banner

If the parameter is not present, treat it as `not-engaged`.


Downsides
---------

Since the consent is passed around in query params, if a user
navigates between domains in some way other than clicking a link,
their consent can get out-of-sync:

- If a user is sent a link with a `cookie_consent` parameter, and then
  clicks it, their consent will be updated without them ever seeing
  the banner.  This is already kind of a problem with the cross-domain
  `_ga` parameter, which will merge two distinct users if shared.

- If a user changes their consent on one domain, and then directly
  navigates to the other (for example, via a bookmark), their consent
  will not be shared.

We think these are acceptable downsides for now.


Alternatives
------------

### Have engaging with the cookie banner update a shared consent store

Using a shared consent store resolves the two downsides described
above.  But the cost is that every request will need to ping this
shared store to get the user's current consent.

We don't think the added implementation complexity and performance
overhead is worth it.

### Store the consent in the account

This is what we currently do.  It works for logged-in users, but
logged-out users would still see two cookie banners.

So, regardless of whether we persist the consent in the account (which
we are likely to do), for logged-out users this is not a solution.

# Tombstone records

## Background

A [`Tombstone` record](https://github.com/alphagov/account-api/blob/main/app/models/tombstone.rb) 
is created whenever an `OidcUser` is deleted.

When this app was originally built it was the canonical place for storing user accounts and data, 
so the `OidcUser` records represented every active account, and the `Tombstone` records represented 
every deleted account. This made sense, as the pages and features for users to set up and manage 
their accounts were spread between DI (`account.gov.uk`) and GOV.UK (`www.gov.uk`).

As more services start using DI's GOV.UK Sign In this structure makes less sense. GOV.UK Sign In 
has records for all the users and knows which services someone has used, so it's more useful to
move all the account management pages to be part of GOV.UK Sign In and treat GOV.UK the same as 
any other service - as an OIDC relying party.

This means that account API no longer has records for every sigle user that's created a GOV.UK 
account and so we don't need to keep a record of every deleted account.

## Decision

We have decided to:

1. Allow multiple tombstone records to exist for the same `sub`[[1]]
2. Delete tombstone records that are older than 30 days[[2]]

This will allow us to delete `OidcUser` records that aren't being used for anything on GOV.UK to 
reduce the amount of personal data we're storing. 

Currently the only use for the GOV.UK account on GOV.UK is to subscribe to email notifications. 
We will initially use the same logic as in email alert API[[3]] to delete GOV.UK accounts which 
have had no active subscriptions for longer than 28 days.

## Consequences

We will no longer be able to measure the total number of GOV.UK accounts by adding the counts of 
`OidcUser` and `Tombstone` records in this app's database.

This information is still available from the Authentication team in Digital Identity and as more 
services onboard the records in this app would have no longer represented the total count of all 
GOV.UK accounts anyway.

[1]: https://github.com/alphagov/account-api/pull/421
[2]: https://github.com/alphagov/account-api/pull/422
[3]: https://github.com/alphagov/email-alert-api/pull/1756
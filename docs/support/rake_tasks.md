# Rake Tasks

There are a number of Rake tasks available to help with administering users.

## User Support Tasks

### Checking a user exists by email address
This will return a message confirming if such a
user can be found.
```ruby
support:find_user[email_address]
```

### Deleting a user (dry run)
This will return a message confirming if the user
exists for deletion, and the user's OICD sub
```ruby
support:delete_user:dry_run[email_address]
```

### Deleting a user
This will delete the user, and confirm the user's OICD sub. Deleting a user
will also remove any email subscriptions they may have in Email Alert API.
```ruby
support:delete_user:real[email_address]
```

### Confirm if a user previously existed by OICD sub
When deleted, a user will create a Tombstone which shares the
user's OICD sub. This task will confirm if a user previously
existed for a given OICD sub,
```ruby
support:find_deleted_user_by_oicd_sub[sub]
```

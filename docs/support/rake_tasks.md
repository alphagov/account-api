# Rake Tasks

There are a number of Rake tasks available to help with
sending content to the Publishing API and administrating users.

## Publishing API Tasks

All content items are found in `config/content_items.yml`

### Publish redirects
Publishes all routes in the `redirects` array
```ruby
publishing_api:publish_redirects
```

### Publish_all special_routes
Publishes all routes in the `special_routes` array

```ruby
publishing_api:publish_special_routes
```

### Publish a help page by name
Publishes a single help page from the help_pages hash, the name
being the first key for the required help page.
```ruby
publishing_api:publish_help_page[name]
```

### Publish single special route by content_id
```ruby
publishing_api:publish_special_route[content_id]
```

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
This will delete the user, and confirm the user's
OICD sub
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

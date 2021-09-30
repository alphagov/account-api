class PopulateLegacySubAndCreateIndex < ActiveRecord::Migration[6.1]
  def up
    OidcUser.update_all("legacy_sub = sub")

    # The SQL standard (and, more relevantly to us, Postgres) allows a
    # nullable field with a unique index to have multiple NULL values.
    # This lets us enforce our desired correctness constraint:
    #
    # sub      | legacy_sub | meaning
    # -------- | ---------- | -------
    # NULL     | NULL       | invalid - sub is not nullable
    # NULL     | not NULL   | invalid - sub is not nullable
    # not NULL | NULL       | user was created post-migration
    # not NULL | not NULL   | user was created pre-migration, and has a unique legacy_sub
    add_index :oidc_users, :legacy_sub, unique: true
  end

  def down
    remove_index :oidc_users, :legacy_sub
  end
end

# CLAUDE.md — redmine_mcp_plugin

## What this is

A Model Context Protocol server that runs **inside Redmine as a plugin**. One endpoint, `POST /mcp`,
authenticated with Redmine's own mechanisms. GPL-2.0, matching Redmine.

Written 2026-08-28. Developed against **Redmine 7.0.0.stale / Rails 8.1.3.1 / Ruby 3.4.1**

## Dynamic client registration

The plugin carries one gem dependency, `doorkeeper-openid_connect`, solely for RFC 7591 dynamic
client registration. This exception avoids maintaining security-sensitive registration protocol code
while allowing MCP clients to obtain a client id without administrator setup. DCR is off by default.

Loading the gem's engine for registration globally prepends behaviour onto Doorkeeper's token
exchange and model layers, which assume the gem's schema exists: the `authorization_code` token
exchange reads the `oauth_openid_requests` nonce table, and the success response reads
`post_logout_redirect_uris` on the application model. The plugin therefore installs the gem's native
schema as a plugin migration under `db/migrate/`, run by `rake redmine:plugins:migrate`. It creates
the `oauth_openid_requests` table (with a cascading foreign key to `oauth_access_grants`) and the
`post_logout_redirect_uris` column on `oauth_applications`. The migration is idempotent and reversible
(`VERSION=0`).

No ID tokens are minted: the gem is configured with no issuer and no signing key, the route skips the
`userinfo`/`discovery` controllers, and the `openid` scope is never requested. The schema only lets
the authorization-code token exchange run the gem's nonce bookkeeping without crashing. The gem is
still loaded lazily (`require: false` plus a lazy `load!` at route-draw time) to avoid a boot-ordering
crash, independent of the schema change.

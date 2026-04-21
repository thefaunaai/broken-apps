# Dossier

A multi-tenant B2B project workspace. Node and SQLite, around 280
lines.

## What Hound Found

**1. Cross-tenant account takeover chained into admin-only report
access.** Hound used Bob's Marrow admin session to reset Mallory's
Pith password across the tenant boundary. It logged in as Mallory,
promoted Mallory from member to admin through the profile API, then
read Pith's confidential engineering salary review. It found the path
on its own. Every finding is independently re-tested.

## Requirements

- Docker (with `docker compose`)
- `make`
- `curl`

No Node, no database, no language runtime on your host.

## Run It

```sh
make up        # build and start the app
make reset     # wipe state, reseed, restart
make down      # stop and remove
```

The app listens on `http://localhost:3000`. Seed credentials are
printed by `make up`.

## Seed Accounts

Two organizations, two users each. All passwords: `password123`.

| Org    | User              | Role   |
|--------|-------------------|--------|
| Pith   | alice@pith.co     | admin  |
| Pith   | mallory@pith.co   | member |
| Marrow | bob@marrow.co     | admin  |
| Marrow | carol@marrow.co   | member |

Sign in as a member of one org. See how far you can reach.

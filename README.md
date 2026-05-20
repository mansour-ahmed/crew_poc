# CrewPoc

A communications platform for hospitality crews. CrewPoc combines a broadcast feed (announcements, peer kudos, birthdays) with auto-managed venue and shift chat channels, so everyone working a property stays aligned without falling back to WhatsApp.

Built on Phoenix + the [Ash Framework](https://ash-hq.org/), backed by PostgreSQL, with a React 19 SPA frontend wired to the backend via [AshTypescript](https://hexdocs.pm/ash_typescript) RPC and typed channels.

> [!NOTE]
> Time-boxed proof of concept, focused on product shape and architecture, not production readiness. Not deployable as-is.

## Demo

  <video src="https://github.com/user-attachments/
  assets/3be7c935-d222-4f75-92e0-41437d668d89" 
  autoplay loop muted playsinline 
  width="100%"></video>


## Features

### Accounts
- Users scoped to an organization with three roles: admin, manager, staff.
- Per-user locale: English, Spanish, Finnish, Portuguese.
- Birthdays and start dates show up as celebration cards in the feed.
- Cookie-backed user picker in the top bar. No real auth in the POC.

### Venues
- Hotels scoped to the organization, each with its own time zone.
- Users can work across multiple venues.
- Creating a venue creates its chat channel. Adding a user to a venue adds them to the venue chat automatically.

### Shifts
- Breakfast / Evening / Overnight blocks per venue, seeded 30 days out.
- Each shift has a chat channel.

### Feed
- Org-wide and venue-scoped announcements.
- Optional Acknowledge button with acked / eligible count.
- Post translation via Google Gemini (through OpenRouter), cached per `(post, locale)`.
- Full-text search across announcements and shoutouts (only backend implemented).

### Recognition
- Peer-to-peer shoutouts.
- Feeds a "most praised" leaderboard.

### Chat
- Two channel kinds: venue and shift.
- Chat messages with per-user read tracking for unread badges.
- Realtime delivery with typed payloads.

## Architecture

- **Backend**: Phoenix 1.8 + Ash 3.x. Domains under `lib/crew_poc/`, web layer under `lib/crew_poc_web/`.
- **Frontend**: React 19 SPA bundled with esbuild. Tailwind v4 + daisyUI. TanStack Query for data, React Hook Form + zod for forms.
- **RPC**: backend actions exposed via AshTypescript. `mix ash_typescript.codegen` regenerates the typed client and channels.
- **No LiveView** for application UI. Only used by `/dev/dashboard` and AshAdmin.

## Prerequisites

- [mise](https://mise.jdx.dev/) — run `mise install` from the project root to pick up the right Elixir/OTP versions.
- [Docker](https://docs.docker.com/get-docker/) — runs PostgreSQL locally via `docker-compose.yml`.
- `OPENROUTER_API_KEY` in your environment if you want post auto-translation to actually call the LLM (we use `google/gemini-3.5-flash` via OpenRouter).

## Getting started

1. Start PostgreSQL:

   ```sh
   docker compose up -d
   ```

2. Install dependencies, set up the database, build assets, and load seed data:

   ```sh
   mix setup
   ```

3. Start the Phoenix server:

   ```sh
   mix phx.server
   ```

   Or inside IEx for live introspection:

   ```sh
   iex -S mix phx.server
   ```

Visit [`localhost:4000`](http://localhost:4000). Switch users from the dropdown in the top bar.

## Useful mix commands

### Project lifecycle

| Command | What it does |
|---|---|
| `mix setup` | Install deps, set up the database, build assets, run seeds. Run once after clone. |
| `mix seed` | Re-run the seeds (idempotent — cleans seeded rows first). |
| `mix phx.server` | Start the app on `http://localhost:4000`. |
| `mix serve:dev` | Same as above, but wraps the server in `op run --env-file .env` to load secrets (e.g. `OPENROUTER_API_KEY`). |
| `mix precommit` | Compile (warnings as errors), check unused deps, check codegen is up to date, format, credo, and tests. **Run this before every commit.** |

### Ash

| Command | What it does |
|---|---|
| `mix ash.setup` | Run all Ash setup steps (DB create, migrate, install Postgres extensions). Used by `mix setup`. |
| `mix ash.reset` | Tear down and re-run setup — drops the DB, recreates it, runs migrations. Follow with `mix seed` to repopulate. |
| `mix ash.codegen <name>` | Generate a migration (and resource snapshot) after a resource change. |
| `mix ash.migrate` | Apply pending migrations. |
| `mix ash.rollback` | Roll back the latest migration. |
| `mix ash_typescript.codegen` | Regenerate the TypeScript RPC client + typed-channel client. Run after exposing a new `rpc_action`. |

### Testing

| Command | What it does |
|---|---|
| `mix test` | Run the test suite. Tests are co-located next to the source they cover. |
| `mix test path/to/file_test.exs:LINE` | Run a single test. |
| `mix test --max-failures 1` | Stop on the first failure — handy while iterating. |
| `mix credo --strict` | Run static analysis with the project's strict ruleset. |

## Database

PostgreSQL runs via Docker Compose. Data is stored in `.postgres-data/` (gitignored).

```sh
docker compose up -d      # start
docker compose stop       # stop
docker compose down       # stop and remove container (data persists on disk)
rm -rf .postgres-data     # wipe all data and start fresh
```

After wiping data, run `mix setup` again to recreate the databases.

### Seed data

`mix setup` seeds a small fixed dataset for local development:

- **1 organization** — Meridian Hotels & Resorts.
- **5 users** — one admin, one manager, three staff. Mixed locales and a spread of birthdays / start dates so the celebration cards always have something to show (one user's birthday is pinned to today).
- **3 venues** — London Mayfair, Dubai Marina, New York Midtown.
- **Venue memberships** — every user belongs to London; the admin and a manager also cover Dubai, and two staff cover New York.
- **Shifts & assignments** — 270 shifts (3 venues × 3 per day × 30 days), with rotating rosters so chat channels have realistic membership.
- **Chat messages** — pre-seeded threads in the London venue and next-shift channels.
- **Posts, acknowledgements, shoutouts** — a handful of each so the feed isn't empty on first load.

Re-run the seeds at any time with `mix seed`. The script is idempotent — it deletes the seeded rows before re-inserting, so you can run it repeatedly without duplicate-key errors.

## Project layout

- `lib/crew_poc/` — Ash domains and resources (business logic).
- `lib/crew_poc_web/` — Phoenix web layer (controllers, channels, plugs, layouts).
- `assets/js/app/` — React SPA (pages, components, hooks).
- `assets/js/ash_rpc.ts`, `ash_types.ts` — generated AshTypescript client (do not edit).
- `priv/repo/migrations/` — Ash-generated database migrations.

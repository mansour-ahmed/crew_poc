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
- Single-organization, multi-user model with three roles: admin, manager, and staff.
- Per-user locale (English / Spanish / Finnish / Portuguese) drives translation rendering across the feed.
- Birthdays and start dates surface as celebration cards in the feed.
- Cookie-backed user picker in the top bar — no real auth in the POC, just switch the active user from a dropdown.

### Venues
- Hotels/sites scoped to the organization, each with its own time zone.
- Users can work across multiple venues from day one.
- Creating a venue auto-provisions its chat channel; adding a user to a venue auto-joins them.

### Shifts
- Scheduled work blocks per venue (Morning / Afternoon / Night), seeded 30 days out.
- Each shift gets a dedicated chat channel; assignments sync channel membership automatically.

### Feed
- Org-wide and venue-scoped announcements (immutable, no edits or deletes).
- Optional **Acknowledge** button with inline acked / eligible count and live updates.
- On-demand LLM translation — when a reader's locale differs from the post's original, the title and body are translated through Google Gemini (via OpenRouter) and cached per `(post, locale)` so subsequent reads are instant.
- Full-text search across announcements and shoutouts.

### Recognition
- Peer-to-peer shoutouts: plain text, one sender → one recipient, no self-shoutouts.
- Searchable alongside posts. Powers a "wins of the week" leaderboard.

### Chat
- Two auto-managed channel kinds: venue channels and shift channels. **No DMs, no user-created groups.**
- Immutable messages with per-user read tracking for unread badges.
- Realtime delivery and typed payloads end-to-end on the frontend.

### Cross-cutting
- **Global search** — one endpoint that fans out to announcements and shoutouts, returns a merged timeline.
- **Realtime** — typed channels for org-wide feed events (new posts, acknowledgements, shoutouts), per-conversation chat events, and a per-user firehose for unread badges across conversations.
- **AshAdmin** — auto-generated admin UI mounted at `/admin` in dev for poking at any resource.

## Architecture

- **Backend**: Phoenix 1.8 + Ash 3.x. Domains under `lib/crew_poc/`, web layer under `lib/crew_poc_web/`.
- **Frontend**: React 19 SPA bundled with esbuild. Tailwind v4 + daisyUI for styling. TanStack Query for data, React Hook Form + zod for forms.
- **RPC**: backend actions are exposed via AshTypescript; `mix ash_typescript.codegen` regenerates the typed client + typed channels.
- **No LiveView** for application UI — it's only pulled in for `/dev/dashboard` and AshAdmin.

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
- **Venue memberships** — every user belongs to London; admins/managers also cover Dubai and New York.
- **Shifts & assignments** — 90 shifts across the next 30 days, with rotating rosters so chat channels have realistic membership.
- **Chat messages** — pre-seeded threads in the London venue and next-shift channels.
- **Posts, acknowledgements, shoutouts** — a handful of each so the feed isn't empty on first load.

Re-run the seeds at any time with `mix seed`. The script is idempotent — it deletes the seeded rows before re-inserting, so you can run it repeatedly without duplicate-key errors.

## Project layout

- `lib/crew_poc/` — Ash domains and resources (business logic).
- `lib/crew_poc_web/` — Phoenix web layer (controllers, channels, plugs, layouts).
- `assets/js/app/` — React SPA (pages, components, hooks).
- `assets/js/ash_rpc.ts`, `ash_types.ts` — generated AshTypescript client (do not edit).
- `priv/repo/migrations/` — Ash-generated database migrations.

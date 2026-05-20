# CrewPoc

A Phoenix web application built on the [Ash Framework](https://ash-hq.org/), backed by PostgreSQL and served via Phoenix LiveView.

## Prerequisites

- [mise](https://mise.jdx.dev/) — run `mise install` from the project root to get the correct Elixir/OTP versions
- [Docker](https://docs.docker.com/get-docker/) — used to run PostgreSQL locally

## Getting started

1. Start PostgreSQL:

   ```sh
   docker compose up -d
   ```

2. Install dependencies and set up the database:

   ```sh
   mix setup
   ```

3. Start the Phoenix server:

   ```sh
   mix phx.server
   ```

   Or inside IEx:

   ```sh
   iex -S mix phx.server
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Database

PostgreSQL runs via Docker Compose. Data is stored in `.postgres-data/` (gitignored).

```sh
docker compose up -d      # start
docker compose stop       # stop
docker compose down       # stop and remove container (data persists)
rm -rf .postgres-data     # wipe all data and start fresh
```

After wiping data, run `mix setup` again to recreate the databases.

## Testing

- `mix test` — run the test suite
- `mix precommit` — compile (warnings as errors), unlock unused deps, format, credo --strict, and test

## Project layout

- `lib/crew_poc/` — Ash domains and resources (business logic)
- `lib/crew_poc_web/` — Phoenix web layer (controllers, LiveViews, components)
- `assets/` — JavaScript and CSS, bundled via esbuild and Tailwind
- `priv/repo/migrations/` — Ash-generated database migrations



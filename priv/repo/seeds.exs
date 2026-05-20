require Ash.Query

import Ecto.Query

alias CrewPoc.Accounts.Organization
alias CrewPoc.Accounts.User
alias CrewPoc.Venues.Venue
alias CrewPoc.Venues.VenueMembership

# ── IDENTIFIERS ─────────────────────────────────────
org_slugs = ["meridian"]

user_emails = [
  "james.okafor@example.com",
  "sofia.reyes@example.com",
  "yuki.tanaka@example.com",
  "amira.hassan@example.com",
  "lucas.oliveira@example.com"
]

venue_slugs = ["london-mayfair", "dubai-marina", "new-york-midtown"]

# ── CLEAN UP (reverse dep order) ────────────────────
CrewPoc.Repo.delete_all(
  from vm in "venue_memberships",
    join: u in "users",
    on: vm.user_id == u.id,
    where: u.email in ^user_emails
)

CrewPoc.Repo.delete_all(from v in "venues", where: v.slug in ^venue_slugs)
CrewPoc.Repo.delete_all(from u in "users", where: u.email in ^user_emails)
CrewPoc.Repo.delete_all(from o in "organizations", where: o.slug in ^org_slugs)

IO.puts("Cleaned existing seed data")

# ── ORGANIZATIONS ─────────────────────────────────────
Ash.bulk_create!(
  [%{name: "Meridian Hotels & Resorts", slug: "meridian"}],
  Organization,
  :create,
  return_errors?: true,
  authorize?: false
)

org_map =
  Organization
  |> Ash.Query.filter(slug in ^org_slugs)
  |> Ash.read!(authorize?: false)
  |> Map.new(&{&1.slug, &1.id})

IO.puts("Seeded #{map_size(org_map)} organizations")

# ── USERS ─────────────────────────────────────────────
meridian_org_id = Map.fetch!(org_map, "meridian")

user_data = [
  %{
    email: "james.okafor@example.com",
    name: "James Okafor",
    role: :admin,
    locale: "es",
    job_title: "Regional Operations Director",
    birthday: ~D[1982-04-12],
    started_at: ~D[2016-03-01],
    organization_id: meridian_org_id
  },
  %{
    email: "sofia.reyes@example.com",
    name: "Sofia Reyes",
    role: :manager,
    locale: "es",
    job_title: "Hotel General Manager",
    birthday: ~D[1988-09-25],
    started_at: ~D[2019-07-15],
    organization_id: meridian_org_id
  },
  %{
    email: "yuki.tanaka@example.com",
    name: "Yuki Tanaka",
    role: :staff,
    locale: "fi",
    job_title: "Guest Relations",
    birthday: ~D[1995-02-14],
    started_at: ~D[2023-04-10],
    organization_id: meridian_org_id
  },
  %{
    email: "amira.hassan@example.com",
    name: "Amira Hassan",
    role: :staff,
    locale: "pt",
    job_title: "Front Desk Supervisor",
    birthday: ~D[1991-11-30],
    started_at: ~D[2021-08-20],
    organization_id: meridian_org_id
  },
  %{
    email: "lucas.oliveira@example.com",
    name: "Lucas Oliveira",
    role: :staff,
    locale: "pt",
    job_title: "Restaurant Manager",
    birthday: ~D[1993-06-08],
    started_at: ~D[2022-01-05],
    organization_id: meridian_org_id
  }
]

Ash.bulk_create!(user_data, User, :create,
  return_errors?: true,
  authorize?: false
)

user_map =
  User
  |> Ash.Query.filter(email in ^user_emails)
  |> Ash.read!(authorize?: false)
  |> Map.new(&{&1.email, &1.id})

IO.puts("Seeded #{map_size(user_map)} users")

# ── VENUES ─────────────────────────────────────────────
venue_data = [
  %{
    name: "Meridian Grand London",
    slug: "london-mayfair",
    city: "London",
    timezone: "Europe/London",
    organization_id: meridian_org_id
  },
  %{
    name: "Meridian Dubai Marina",
    slug: "dubai-marina",
    city: "Dubai",
    timezone: "Asia/Dubai",
    organization_id: meridian_org_id
  },
  %{
    name: "Meridian New York Midtown",
    slug: "new-york-midtown",
    city: "New York",
    timezone: "America/New_York",
    organization_id: meridian_org_id
  }
]

Ash.bulk_create!(venue_data, Venue, :create,
  return_errors?: true,
  authorize?: false
)

venue_map =
  Venue
  |> Ash.Query.filter(slug in ^venue_slugs)
  |> Ash.read!(authorize?: false)
  |> Map.new(&{&1.slug, &1.id})

IO.puts("Seeded #{map_size(venue_map)} venues")

# ── VENUE MEMBERSHIPS ─────────────────────────────────
london_id = Map.fetch!(venue_map, "london-mayfair")
dubai_id = Map.fetch!(venue_map, "dubai-marina")
new_york_id = Map.fetch!(venue_map, "new-york-midtown")

membership_data =
  Enum.map(user_emails, fn email ->
    %{user_id: Map.fetch!(user_map, email), venue_id: london_id, organization_id: meridian_org_id}
  end) ++
    [
      %{
        user_id: Map.fetch!(user_map, "james.okafor@example.com"),
        venue_id: dubai_id,
        organization_id: meridian_org_id
      },
      %{
        user_id: Map.fetch!(user_map, "sofia.reyes@example.com"),
        venue_id: dubai_id,
        organization_id: meridian_org_id
      },
      %{
        user_id: Map.fetch!(user_map, "amira.hassan@example.com"),
        venue_id: new_york_id,
        organization_id: meridian_org_id
      },
      %{
        user_id: Map.fetch!(user_map, "lucas.oliveira@example.com"),
        venue_id: new_york_id,
        organization_id: meridian_org_id
      }
    ]

Ash.bulk_create!(membership_data, VenueMembership, :create,
  return_errors?: true,
  authorize?: false
)

IO.puts("Seeded #{length(membership_data)} venue memberships")
IO.puts("Seeds complete!")

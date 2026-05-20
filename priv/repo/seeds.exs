require Ash.Query

import Ecto.Query

alias CrewPoc.Accounts.Organization
alias CrewPoc.Accounts.User
alias CrewPoc.Chat.Conversation
alias CrewPoc.Chat.Message
alias CrewPoc.Feed.Acknowledgement
alias CrewPoc.Feed.Post
alias CrewPoc.Recognition.Shoutout
alias CrewPoc.Shifts.Shift
alias CrewPoc.Shifts.ShiftAssignment
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

# ── CLEAN UP ────────────────────────────────────────
# Every org-scoped table cascade-deletes from `organizations`, either directly
# via `organization_id` (`on_delete: :delete_all`) or transitively via Ash
# `references on_delete: :delete` on the resource (e.g. memberships cascade
# from venues/users/conversations, which in turn cascade from the org).
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

# Pin Yuki's birthday to today's month/day so the feed always shows a
# celebration card when the seeds are run.
today_for_birthday = Date.utc_today()

yuki_birthday =
  Date.new!(1995, today_for_birthday.month, today_for_birthday.day)

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
    birthday: yuki_birthday,
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

# ── SHIFTS ────────────────────────────────────────────
# 3 shifts/day (Morning, Afternoon, Night) for the next 30 days, per venue.
today = Date.utc_today()
venue_ids = [london_id, dubai_id, new_york_id]

shift_templates = [
  {"Morning", ~T[06:00:00], ~T[14:00:00], 0},
  {"Afternoon", ~T[14:00:00], ~T[22:00:00], 0},
  {"Night", ~T[22:00:00], ~T[06:00:00], 1}
]

shift_data =
  for venue_id <- venue_ids,
      day_offset <- 0..29,
      {name, start_time, end_time, end_day_offset} <- shift_templates do
    date = Date.add(today, day_offset)

    %{
      name: name,
      starts_at: DateTime.new!(date, start_time, "Etc/UTC"),
      ends_at: DateTime.new!(Date.add(date, end_day_offset), end_time, "Etc/UTC"),
      venue_id: venue_id,
      organization_id: meridian_org_id
    }
  end

Ash.bulk_create!(shift_data, Shift, :create,
  return_errors?: true,
  authorize?: false
)

IO.puts("Seeded #{length(shift_data)} shifts")

# ── CHAT (venue + next-active-shift conversations) ────
# Venue conversation memberships are auto-created by VenueMembership above.
# Shift conversation memberships are auto-created by ShiftAssignment, so we
# seed assignments across several upcoming shifts to spread users around.
james = User |> Ash.get!(Map.fetch!(user_map, "james.okafor@example.com"), authorize?: false)
sofia = User |> Ash.get!(Map.fetch!(user_map, "sofia.reyes@example.com"), authorize?: false)
yuki = User |> Ash.get!(Map.fetch!(user_map, "yuki.tanaka@example.com"), authorize?: false)
amira = User |> Ash.get!(Map.fetch!(user_map, "amira.hassan@example.com"), authorize?: false)
lucas = User |> Ash.get!(Map.fetch!(user_map, "lucas.oliveira@example.com"), authorize?: false)

london_venue_conversation =
  Conversation
  |> Ash.Query.filter(venue_id == ^london_id and kind == :venue_channel)
  |> Ash.read_one!(authorize?: false)

now = DateTime.utc_now()

# Next 10 upcoming/active London shifts, ordered soonest-first.
upcoming_london_shifts =
  Shift
  |> Ash.Query.filter(venue_id == ^london_id and ends_at > ^now)
  |> Ash.Query.sort(starts_at: :asc)
  |> Ash.Query.limit(10)
  |> Ash.read!(authorize?: false)

next_london_shift = List.first(upcoming_london_shifts)

next_shift_conversation =
  Conversation
  |> Ash.Query.filter(shift_id == ^next_london_shift.id and kind == :shift_channel)
  |> Ash.read_one!(authorize?: false)

# Per-shift rosters: every user works the next shift (so chat has activity for
# everyone), then subsequent shifts get partial overlapping rosters so users
# are spread across the schedule rather than all clustered on one shift.
london_rosters = [
  [james, sofia, yuki, amira, lucas],
  [sofia, yuki, lucas],
  [james, amira, lucas],
  [sofia, yuki, amira],
  [james, yuki, lucas],
  [sofia, amira, lucas],
  [james, sofia, yuki],
  [yuki, amira, lucas],
  [james, sofia, amira],
  [sofia, yuki, lucas]
]

shift_assignment_inputs =
  for {shift, roster} <- Enum.zip(upcoming_london_shifts, london_rosters),
      user <- roster do
    %{
      shift_id: shift.id,
      user_id: user.id,
      organization_id: meridian_org_id
    }
  end

Ash.bulk_create!(shift_assignment_inputs, ShiftAssignment, :create,
  return_errors?: true,
  authorize?: false
)

IO.puts(
  "Seeded #{length(shift_assignment_inputs)} shift assignments across upcoming London shifts"
)

venue_messages = [
  {sofia, "Morning team — quick reminder we have a VIP arrival at 14:00 today."},
  {amira, "Got it. Suite 1207 is prepped and the welcome amenity is on its way up."},
  {james, "Thanks both. Loop me in if anything slips."},
  {yuki, "Front desk is fully staffed through the evening, all good here."},
  {lucas, "Restaurant has the dietary notes on file — table 12 reserved at 19:30."},
  {sofia, "Perfect. Let's keep the channel open if anything changes."}
]

shift_messages = [
  {amira, "Handover from morning: room 904 still waiting on engineering."},
  {yuki, "Copy — I'll chase engineering and update once it's resolved."},
  {lucas, "Bar covers tonight look heavy, may need a runner around 20:00."},
  {sofia, "I'll float over from the lobby if it gets hectic."}
]

for {actor, body} <- venue_messages do
  Message
  |> Ash.Changeset.for_create(
    :create,
    %{conversation_id: london_venue_conversation.id, body: body},
    actor: actor
  )
  |> Ash.create!(actor: actor)
end

for {actor, body} <- shift_messages do
  Message
  |> Ash.Changeset.for_create(
    :create,
    %{conversation_id: next_shift_conversation.id, body: body},
    actor: actor
  )
  |> Ash.create!(actor: actor)
end

IO.puts("Seeded #{length(venue_messages) + length(shift_messages)} chat messages")

# ── POSTS ─────────────────────────────────────────────
post_inputs = [
  {james,
   %{
     title: "Q2 brand standards refresh",
     body:
       "We're rolling out updated brand standards across all properties next month. " <>
         "Please review the attached guide and acknowledge once you've read it.",
     requires_acknowledgement: true,
     venue_id: nil
   }},
  {sofia,
   %{
     title: "London — new check-in flow goes live Monday",
     body:
       "Front desk will switch to the streamlined check-in flow starting Monday. " <>
         "Training videos are in the shared drive. Please complete before your next shift.",
     requires_acknowledgement: true,
     venue_id: london_id
   }},
  {james,
   %{
     title: "Welcome to Meridian Crew",
     body:
       "Excited to launch our new crew app. Use the feed for announcements, " <>
         "the chat for venue and shift coordination, and shoutouts to recognize teammates.",
     requires_acknowledgement: false,
     venue_id: nil
   }},
  {lucas,
   %{
     title: "Restaurant menu update — spring tasting",
     body:
       "The spring tasting menu launches this weekend at the London restaurant. " <>
         "Please review allergen notes before your next service.",
     requires_acknowledgement: false,
     venue_id: london_id
   }}
]

posts_by_title =
  for {actor, attrs} <- post_inputs, into: %{} do
    post =
      Post
      |> Ash.Changeset.for_create(:create, attrs, actor: actor)
      |> Ash.create!(actor: actor)

    {post.title, post}
  end

IO.puts("Seeded #{map_size(posts_by_title)} posts")

# ── ACKNOWLEDGEMENTS ──────────────────────────────────
brand_post = Map.fetch!(posts_by_title, "Q2 brand standards refresh")
checkin_post = Map.fetch!(posts_by_title, "London — new check-in flow goes live Monday")

ack_inputs = [
  {sofia, brand_post},
  {amira, brand_post},
  {lucas, brand_post},
  {yuki, checkin_post},
  {amira, checkin_post}
]

for {actor, post} <- ack_inputs do
  Acknowledgement
  |> Ash.Changeset.for_create(:create, %{post_id: post.id}, actor: actor)
  |> Ash.create!(actor: actor)
end

IO.puts("Seeded #{length(ack_inputs)} acknowledgements")

# ── SHOUTOUTS ─────────────────────────────────────────
shoutout_inputs = [
  {sofia, amira, "Amira saved the evening with that last-minute suite reshuffle — total pro."},
  {james, sofia, "Sofia's handling of the VIP arrival yesterday was textbook. Thank you."},
  {yuki, lucas, "Lucas covered my dinner rush without breaking a sweat. Legend."},
  {amira, yuki, "Yuki spotted the double-booking before it became a problem. Sharp eyes!"},
  {lucas, amira, "Amira's a magician at the front desk. Guest feedback this week is glowing."}
]

for {sender, recipient, body} <- shoutout_inputs do
  Shoutout
  |> Ash.Changeset.for_create(:create, %{recipient_id: recipient.id, body: body}, actor: sender)
  |> Ash.create!(actor: sender)
end

IO.puts("Seeded #{length(shoutout_inputs)} shoutouts")

IO.puts("Seeds complete!")

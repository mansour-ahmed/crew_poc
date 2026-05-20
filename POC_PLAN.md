# Crew POC — Plan

A communications platform for hospitality businesses. Two intertwined goals:

1. **Workforce alignment & retention** — make staff feel part of something bigger than their day-to-day.
2. **WhatsApp replacement** — internal 1:1 and group communications.

This document is the source of truth for the POC. It is iterated section by section
(domains → actions → frontend → work split → milestones).

---

## 1. POC Scope (feature checklist)

### Alignment / culture
- [ ] Organization-wide feed (announcements)
- [ ] Venue-specific feed (nested under organization)
- [ ] Peer shoutouts / kudos (plain text — no values tagging)
- [ ] Auto-translate toggle per post
- [ ] Wins of the week / venue leaderboards
- [ ] Birthdays & work anniversaries surfaced in feed
- [ ] "Acknowledge" button on announcements → admin analytics
- [ ] Searchable across posts and shoutouts

### Chat
- [ ] Venue channel (auto-membership = all venue staff)
- [ ] Shift channel (auto-membership = assigned shift staff)

### Explicitly cut
- ~~Organization "Values" tagging on shoutouts~~ — shoutouts stay plain text.
- ~~1:1 direct messages~~ — chat is venue + shift channels only.
- ~~Free-form group chats~~ — no user-created groups.
- ~~Searchable chat~~ — search covers posts + shoutouts only.
- ~~Pulse surveys (lightweight: 1 question, 1–5 scale)~~ — dropped from POC scope; the `Engagement` domain (§3.6 / §7.6) and Slice C (§9.2) are preserved below as **CANCELLED** for future revival.

---

## 2. Domain Map

Six Ash domains, layered by dependency. Each is a candidate for an isolated work-stream.
(`Engagement` was originally a seventh domain — pulse surveys — but is cancelled for the POC.
See §3.6 / §7.6 / Slice C in §9.2 for the preserved-but-out-of-scope spec.)

```
            ┌──────────────────┐
            │     Accounts     │   foundation: User, Organization
            └────────┬─────────┘
                     │
            ┌────────┴─────────┐
            │      Venues      │   physical sites, staff-to-site mapping
            └────────┬─────────┘
                     │
            ┌────────┴─────────┐
            │      Shifts      │   scheduled work blocks, staff-to-shift mapping
            └────────┬─────────┘
        ┌────────────┼──────────────┐
        │            │              │
   ┌────┴───┐   ┌────┴─────┐   ┌────┴─────┐
   │  Feed  │   │Recognition│  │   Chat   │
   └────────┘   └──────────┘   └──────────┘
   posts/acks   shoutouts      venue + shift
                                channels +
                                messages
```

Cancelled (out of POC scope): `Engagement` (pulse surveys + responses).

Cross-cutting services (not domains):
- **Translation** — wraps an external API; caches translations against posts.
- **Search** — per-resource `:search` read actions (`contains/2` + `pg_trgm` GIN) aggregated by a thin `CrewPoc.Search` module across posts and shoutouts (not messages). Details in §4.3.

---

## 3. Domains in detail

### 3.1 Accounts

The identity & org backbone. Everything is scoped through here.

**Resources**

| Resource       | Purpose                                                        |
|----------------|----------------------------------------------------------------|
| `Organization` | The hospitality brand (e.g. "Scandic", "Hilton").              |
| `User`         | A staff member. Belongs to one organization. Carries `role` directly. |

**`Organization` fields**
- `id :: :uuid` (PK)
- `name :: :string` — required, unique.
- `slug :: :string` — URL-safe, lowercased, unique. Auto-generated from `name` on create if not provided.
- timestamps.

**`User` fields**
- `id :: :uuid` (PK)
- `email :: :string` — **globally unique**, required.
- `name :: :string` — single full-name string. Initials for the avatar circle are computed client-side from whitespace splits.
- `organization_id :: :uuid` — org scope. Required.
- `role :: :atom` — `one_of: [:admin, :manager, :staff]`, default `:staff`.
- `locale :: :string` — ISO 639-1 language code, e.g. `"en"`, `"fi"`, `"pt"`, `"es"`. Required. Defaults to `"en"`. Drives translation rendering.
- `job_title :: :string` — free text. Required.
- `birthday :: :date` — required. Year is ignored at display time.
- `started_at :: :date` — **required**. Drives work-anniversary calculations.
- timestamps.
- Venue assignment is many-to-many through `VenueMembership` (no `home_venue_id`). A user can work across multiple venues from day one.

Avatars are **not stored**. The frontend renders a deterministic colored circle with the user's initials, color from `hash(user.id)`. One small React component, zero backend.

**Auth — skipped for the POC.**
- No AshAuthentication. Instead: a user picker in the top bar lets you switch the active user. Selection persists in a cookie.
- A `CrewPocWeb.Plugs.CurrentUser` plug reads the cookie, loads the user, sets `conn.assigns.current_user`.
- For typed channels (added in Phase 2 when chat/feed realtime is wired up): `UserSocket.connect/2` will read the same signed cookie via `Plug.Crypto.verify/4` and stuff `current_user_id` into the socket assigns.
- Every Ash action call passes `actor: conn.assigns.current_user`. Policies still run — we just trust the cookie instead of a session.
- Trade-off acknowledged: this is a demo affordance, not real auth. Easy to swap in `ash_authentication` later (it's a single drop-in).

**Key calculations / aggregates**
- `User.birthday_today?` — boolean calc
- `User.work_anniversary_today?` — boolean calc
- `Organization.staff_count` — count aggregate over users

**Org scoping**
- Every resource below carries a required `organization_id` FK. See §4.1 for details — not real multi-tenancy, just scoping.

---

### 3.2 Venues

Physical sites within an organization.

**Resources**

| Resource          | Purpose                                                      |
|-------------------|--------------------------------------------------------------|
| `Venue`           | A hotel/site.                                                          |
| `VenueMembership` | User ↔ Venue join. Flat many-to-many.                                  |

**`Venue` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope. Required.
- `name :: :string` — required.
- `slug :: :string` — URL-safe, unique within the org. Auto-generated from `name` on create.
- `city :: :string` — required.
- `timezone :: :string` — IANA tz, e.g. `"Europe/Helsinki"`. Used for formatting `Shift.starts_at`/`ends_at` and post timestamps in the venue feed.
- timestamps.

**`VenueMembership` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `venue_id :: :uuid`
- `user_id :: :uuid`
- timestamps.
- Unique constraint: `(user_id, venue_id)`.

**Notes**
- No "primary venue" concept. UI doesn't pick a default.
- Venue manager role: a user with `role == :manager` can manage any venue they are a member of.

---

### 3.3 Shifts

Scheduled work blocks within a venue. Exists solely to back **shift channels** in chat — we don't model rotas, breaks, or pay.

**Resources**

| Resource          | Purpose                                                                |
|-------------------|------------------------------------------------------------------------|
| `Shift`           | A scheduled work block at a venue.                              |
| `ShiftAssignment` | Shift ↔ User join. Drives shift channel membership.              |

**`Shift` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `venue_id :: :uuid` — required.
- `name :: :string` — free text, e.g. "Friday evening front-desk". Captures role/department; no separate enum.
- `starts_at :: :utc_datetime` — required.
- `ends_at :: :utc_datetime` — required, must be > `starts_at` (validation + DB check constraint).
- timestamps.
- **Calculation** `status :: :atom` — `:upcoming | :active | :finished`, computed from `starts_at`/`ends_at` and `now()`. No stored column.

**`ShiftAssignment` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `shift_id :: :uuid`
- `user_id :: :uuid` — must already have `VenueMembership` for `shift.venue_id` (validate in the create action).
- timestamps.
- Unique constraint: `(shift_id, user_id)`.

**Notes**
- No actions for "swap shift", "request cover", etc. — out of scope.
- **No admin UI.** Shifts and assignments are created in `priv/repo/seeds.exs` only. The demo shows shift channels already populated; we don't need a "create shift" screen.
- **Membership sync** — `ShiftAssignment` create/delete fires an `after_action` change (or Ash notifier) that adds/removes the matching `ConversationMembership` on the shift channel. Same pattern as `VenueMembership` ↔ venue channel.

---

### 3.4 Feed

The broadcast layer: announcements, acknowledgements, and the cultural surface that aggregates shoutouts/birthdays/anniversaries.

**Resources**

| Resource          | Purpose                                                       |
|-------------------|---------------------------------------------------------------|
| `Post`            | An announcement. Scoped to org OR a specific venue.           |
| `PostTranslation` | Cached translation of a post body into a target locale.       |
| `Acknowledgement` | A user clicked "Acknowledge" on a post.                       |

**`Post` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope. Required.
- `venue_id :: :uuid` — **nullable**. `nil` ⇒ org-wide; set ⇒ venue-scoped.
- `author_id :: :uuid` — the User who posted.
- `title :: :string` — required.
- `body :: :string` — required, long text.
- `original_locale :: :string` — ISO 639-1 language code. Defaults to `author.locale` on create.
- `auto_translate :: :boolean` — default `false`. Author opts in via a checkbox.
- `requires_acknowledgement :: :boolean` — default `false`. Drives the visible Ack button.
- `published_at :: :utc_datetime` — set to `now()` on create. No drafts, no scheduling.
- timestamps.

**`PostTranslation` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `post_id :: :uuid`
- `target_locale :: :string` — ISO 639-1 language code.
- `title :: :string` — translated title.
- `body :: :string` — translated body.
- timestamps.
- Unique constraint: `(post_id, target_locale)`.

**`Acknowledgement` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `post_id :: :uuid`
- `user_id :: :uuid`
- timestamps. (`inserted_at` = when acked.)
- Unique constraint: `(post_id, user_id)`.

**Visibility rules (policies)**
- Org-wide posts: any user in the org.
- Venue posts: any user whose `VenueMembership` includes the venue.
- Org admin can post org-wide; venue manager can post to their venue; staff cannot post (POC).

**Translation flow**
- On read, if `post.auto_translate` and `reader.locale != post.original_locale`:
  - Look up `PostTranslation(post_id, locale)` cache.
  - Miss → fire the prompt-backed action on `PostTranslation` (translates both `title` and `body` in a single call), insert the row, return.
- Title and body always travel together — never partial translations.

**Acknowledgement count (inline)**
- Each post shows `ack_count / eligible_audience_count` inline to all readers. The Ack button reflects whether the current user has acknowledged.
- Eligible audience = org user count (org-wide) or venue user count (venue-scoped). Computed as an aggregate.
- No standalone admin analytics dashboard in the POC.

**Merged feed stream**
The UI "feed" is a single chronological stream interleaving:
- Posts (announcements)
- Recent shoutouts (from `Recognition`)
- Today's birthdays / anniversaries (from `Accounts` calculations — one synthetic item per celebrating user per day)

Approach: a `Feed.list_items(actor, opts)` domain function returns a typed union list sorted by timestamp. Each item carries a `kind :: :post | :shoutout | :celebration` discriminator + the underlying record. The frontend switches on `kind` and renders the matching component.

Pagination: offset paging via a unioned subquery, or simpler — fetch the latest N of each kind, merge in Elixir, return. POC scale makes the simpler path fine.

---

### 3.5 Recognition

Peer-to-peer kudos. Plain text only — no values tagging in the POC.

**Resources**

| Resource    | Purpose                                                              |
|-------------|----------------------------------------------------------------------|
| `Shoutout`  | A peer kudos: one sender → one recipient, plain text.                |

**`Shoutout` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `sender_id :: :uuid` — User.
- `recipient_id :: :uuid` — User. Single recipient only; group thank-yous are multiple shoutouts.
- `body :: :string` — required.
- `published_at :: :utc_datetime` — defaults to `now()` on create.
- timestamps.

**Rules / validations**
- `sender_id != recipient_id` (no self-shoutouts) — changeset + DB check constraint.
- Same organization on sender and recipient — guaranteed by the org-scope FK + the auto-applied filter.

**Visibility**
- Always org-wide. Every user in the org sees every shoutout on the feed. No venue scoping.

**Wins-of-the-week leaderboard**
- `Recognition.top_recipients_this_week/1` query: top 5 shoutout recipients in the last 7 days.
- Hardcoded 7-day window, no tabs, no other ranges. One aggregate, one UI panel.

---

### 3.6 Engagement (Pulse Surveys) — **CANCELLED for POC**

> **Status: cancelled.** The pulse-surveys feature is dropped from the POC. The spec below is preserved verbatim so we can revive the domain in a follow-up without redesigning from scratch. Nothing in §3.6 should be implemented during the current scope. Feed surface integration in §3.4 (the "active survey card") is also out of scope until this is revived.

Lightweight check-ins. Admin asks the org "How are things this week?", staff respond, admin sees aggregate.

**Resources**

| Resource         | Purpose                                                            |
|------------------|--------------------------------------------------------------------|
| `PulseSurvey`    | A single-question check-in scoped to the organization.            |
| `PulseResponse`  | A user's one-shot score for a survey.                              |

**`PulseSurvey` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `prompt :: :string` — required, e.g. "How are you feeling this week?"
- `scale_min :: :integer` — required, default `1`.
- `scale_max :: :integer` — required, default `5`. Must be > `scale_min`.
- `closes_at :: :utc_datetime` — required. Survey is active while `now() < closes_at`; otherwise closed. No manual close button, no `closed_at`.
- timestamps.
- **Active-ness is time-based**, so we enforce "at most one active per org" in the create action (precondition: no `PulseSurvey` for this org with `closes_at > now()`). Cheaper than partial indexes on computed columns.
- **Calculation** `active? :: :boolean` — `now() < closes_at`. Used in queries + admin view.

**`PulseResponse` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `pulse_survey_id :: :uuid`
- `user_id :: :uuid`
- `score :: :integer` — validated at action-level against `[survey.scale_min, survey.scale_max]`.
- timestamps.
- Unique constraint: `(pulse_survey_id, user_id)`. **No update action** — one-shot submission.

**POC scope**
- Single-question, org-wide surveys only. No venue scoping. No multi-question construct.
- **At most one active survey per org** — enforced as a precondition in the `:create` action (no existing row with `closes_at > now()`).
- **Auto-close** when `closes_at` elapses — no manual close button, no `closed_at` field, no `opens_at`. Open from creation until `closes_at`.
- Scale is configurable per survey (`scale_min`, `scale_max`) so admins can ask "1–5 mood" or "1–10 NPS-style" without code change. The UI renders `scale_max - scale_min + 1` buttons.
- Responses are attributed (admin sees who responded, but only displays the aggregate). No anonymous flag, no `comment` field.

**Admin view**
- Avg score, response count, response rate (responses / org user count), distribution per score.
- All derivable as Ash aggregates / calculations.

**Feed surface**
- The active survey appears as a prominent card at the top of the merged feed. Once the user responds, the card collapses to "Thanks — you scored X/max".

---

### 3.7 Chat

Conversational messaging. The "replace WhatsApp" half of the brief — but slimmed to **only** auto-managed channels. No user-created conversations, no DMs, no group chats.

**Resources**

| Resource                  | Purpose                                                              |
|---------------------------|----------------------------------------------------------------------|
| `Conversation`            | An auto-managed group channel.                                        |
| `ConversationMembership`  | User ↔ Conversation join. Drives membership + per-user unread state.  |
| `Message`                 | An immutable text message in a conversation.                          |

**`Conversation` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `kind :: :atom` — `one_of: [:venue_channel, :shift_channel]`.
- `venue_id :: :uuid` — required for both kinds (shift channels denormalize the venue for query convenience).
- `shift_id :: :uuid` — required iff `kind == :shift_channel`, null otherwise.
- `title :: :string` — **stored, denormalized on create** from `venue.name` or `shift.name`. Avoids a join on every sidebar list.
- timestamps.
- Unique constraints: `(venue_id) WHERE kind = :venue_channel`; `(shift_id) WHERE kind = :shift_channel`.

**`ConversationMembership` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `conversation_id :: :uuid`
- `user_id :: :uuid`
- `last_read_at :: :utc_datetime` — nullable. Null = never read.
- timestamps.
- Unique constraint: `(conversation_id, user_id)`.

**`Message` fields**
- `id :: :uuid` (PK)
- `organization_id :: :uuid` — org scope.
- `conversation_id :: :uuid`
- `author_id :: :uuid`
- `body :: :string` — required, non-empty.
- timestamps. (`inserted_at` = sent-at.)
- **Immutable** — no edit or delete actions in the POC.

**Conversation kinds**
- `:venue_channel` — auto-created when a `Venue` is created. Membership auto-synced from `VenueMembership` (add/remove).
- `:shift_channel` — auto-created when a `Shift` is created. Membership auto-synced from `ShiftAssignment` (add/remove).

**Read tracking**
- Frontend calls `Chat.mark_read(conversation_id)` when the user opens or focuses a conversation (and after sending a message).
- The action sets `last_read_at = now()` for the caller's membership and broadcasts `unread_changed` on the `user:#{user_id}` channel.
- Unread count for any conversation = `Message` rows where `inserted_at > membership.last_read_at`. Computed as an aggregate.

**Realtime — via `AshTypescript.TypedChannel`**
- We use Ash PubSub publications + `AshTypescript.TypedChannel` rather than hand-rolled `Phoenix.Channel`s. Payloads are derived from `transform :some_calc` (`:auto`-typed calculations on the resource), so the TS event types are generated by `mix ash_typescript.codegen` alongside the RPC client — no manually-typed socket payloads.
- **Two channels** (chat needs both):
  - `chat:conversation:*` — per-conversation events: `message_created`, `read_advanced`. Joined when the user opens a conversation.
  - `user:*` — per-user firehose for cross-conversation unread badges: `unread_changed`. Always joined while the user is signed in, so the sidebar can show unread counts for conversations the user hasn't opened. No mention events (mentions are out of scope).
- Authorization happens in each channel's `join/3` — we own that (verify the user belongs to the conversation / matches the user id).
- LiveView is **not** used for chat. Vanilla Phoenix Channels + typed payloads only.

---

## 4. Cross-cutting concerns

### 4.1 Organization scoping
- Every resource (except `Organization`) carries a required `organization_id` foreign key.
- No Ash multitenancy mechanism is used. Org scoping is applied explicitly via filters (`filter: [organization_id: id]`) or policies where needed. Single seeded org for the demo.

### 4.2 Translation via `ash_ai` (prompt-backed action)

`ash_ai` is already a dependency. Translation lives on `PostTranslation` as a **prompt-backed action** — `ash_ai` handles the LLM call, structured output, and ReqLLM integration. We don't write any raw HTTP code.

**Provider:** Google Gemini via OpenRouter (using ReqLLM). Configure in `runtime.exs`:

```elixir
config :req_llm, openrouter_api_key: System.fetch_env!("OPENROUTER_API_KEY")
```

Run `mix igniter.install ash_ai` if extensions aren't yet wired up.

**Shape — on `PostTranslation`:**

```elixir
defmodule CrewPoc.Feed.PostTranslation do
  use Ash.Resource,
    domain: CrewPoc.Feed,
    extensions: [AshAi],
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false
    attribute :body, :string, allow_nil?: false
    attribute :target_locale, :atom, constraints: [one_of: [:fi, :pt, :es]]
    # ... organization_id, post_id, timestamps
  end

  actions do
    # Prompt-backed action: one LLM call translates title + body together.
    action :translate, TranslatedPost do
      argument :title, :string, allow_nil?: false
      argument :body, :string, allow_nil?: false
      argument :source_locale, :atom, allow_nil?: false
      argument :target_locale, :atom, allow_nil?: false

      run prompt("openrouter:google/gemini-3.5-flash",
        prompt: """
        Translate the following announcement from <%= @input.arguments.source_locale %> to <%= @input.arguments.target_locale %>.
        Return the translated title and body. Do not add commentary, quotes, or labels.

        Title: <%= @input.arguments.title %>
        Body: <%= @input.arguments.body %>
        """,
        tools: false
      )
    end

    # Cache-aware create: looks up existing row, falls back to :translate, persists.
    create :ensure_for do
      # custom change that performs the lookup-or-translate
    end
  end

  # unique constraint on (post_id, target_locale)
end

# Return type for the prompt action — `ash_ai` derives the JSON schema for structured output.
defmodule TranslatedPost do
  use Ash.TypedStruct

  typed_struct do
    field :title, :string, allow_nil?: false
    field :body, :string, allow_nil?: false
  end
end
```

**Read flow:**
- Frontend renders a post. If `post.auto_translate == true` and `reader.locale != post.original_locale`, it asks the backend for the translation.
- Backend calls `Feed.ensure_translation(post_id: id, target_locale: reader.locale)`. Cached row returned if present; otherwise the prompt-backed `:translate` action fires, caches, returns.
- Messages are **not** translated.

**Cost control:** only triggered on-demand (no bulk pre-translation, no background warming). `gpt-4o-mini` is fast and cheap enough for demo volume.

### 4.3 Search

Per-resource `:search` read actions, fanned out by a thin domain-level aggregator. Following the canonical Ash recipe — no tsvector columns, no separate `Search` resource.

**On each searchable resource** (`Feed.Post`, `Recognition.Shoutout`):

```elixir
read :search do
  argument :query, :ci_string do
    constraints allow_empty?: true
    default ""
  end

  filter expr(contains(body, ^arg(:query)))
  pagination offset?: true, default_limit: 12
end
```

- Uses `:ci_string` for case-insensitive matching.
- `contains/2` compiles to `ILIKE '%query%'`.
- Policies on the resource still apply — search inherits them for free.

**Index** — install `pg_trgm` once (in `Repo.installed_extensions/0`) and add a GIN index per searchable field:

```elixir
postgres do
  custom_indexes do
    index "body gin_trgm_ops", name: "posts_body_gin_index", using: "GIN"
  end
end
```

**Code interface** — domain exposes a clean call:

```elixir
# In Feed domain
resource Post do
  define :search_posts, action: :search, args: [:query]
end
```

**Cross-domain aggregator** — `CrewPoc.Search.global(actor, query)` calls `Feed.search_posts!` and `Recognition.search_shoutouts!`, merges by `inserted_at`. Frontend gets one endpoint.

Chat messages are **not** searchable in the POC.

### 4.4 Authorization
Three roles via `User.role`:
- `:admin` — full org control; posts org-wide announcements. (Originally also created pulse surveys — cancelled.)
- `:manager` — posts venue-scoped announcements for venues they belong to.
- `:staff` — reads feed; gives shoutouts; participates in chat. (Originally also responded to pulse — cancelled.)

Policies live on the resource. Standard helpers: `can_post_org_wide?`, `can_post_to_venue?`.

### 4.5 Realtime — typed channels everywhere
- `AshTypescript.TypedChannel` is the single realtime mechanism for the POC. Every push from server → client goes through an Ash PubSub publication with a `transform :calc` so the payload is typed end-to-end.
- Three channels in scope:
  - `chat:conversation:*` — per-conversation chat events (`message_created`, `read_advanced`). Messages are immutable so no update/delete events.
  - `user:*` — per-user firehose for unread badges across conversations (`unread_changed`).
  - `org:*` — live feed updates: `post_created`, `acknowledgement_added`, `shoutout_created`. Lets the feed refresh without polling. (`pulse_response_recorded` was planned here but is cancelled along with Engagement.)
- Requires Ash >= 3.21.1. Pin that in `mix.exs`.
- Channel join callbacks own authorization — the typed-channel layer doesn't enforce it.

### 4.6 Frontend (React + AshTypescript RPC)
- All commands/queries exposed via `rpc_action` entries; `mix ash_typescript.codegen` regenerates the RPC client and the typed-channel client in one pass.
- No LiveView. No HEEx beyond the existing root + SPA mount.

---

## 5. Open decisions

Most of the original open list has been resolved through the walk-through. Remaining:

_All major decisions resolved. Remaining items are implementation details to settle as we build._

**Resolved during this iteration:**
- Seed shape: 1 org (Meridian Hotels & Resorts), 3 international venues (London, Dubai, New York), 20 users with globally diverse names across **fi / pt / es** locales, 5 shifts, 10 announcements, 15 shoutouts. (~~1 active pulse survey~~ removed — Engagement is cancelled.)
- LLM provider: **Google Gemini** via OpenRouter + ReqLLM (`google/gemini-3.5-flash` for translation). `OPENROUTER_API_KEY` in env.
- Single org per user, no Membership resource → use `User.role`.
- Venue assignment is flat m2m, no primary/secondary kind.
- Shifts: separate domain, seeded only, no admin UI.
- Chat: venue + shift channels only, no DMs, no group chats, no chat search, no mentions, no chat translation. Read receipts + unread badges kept.
- Feed: merged stream (posts + shoutouts + celebrations only — no active-pulse card), per-post translate toggle, inline ack count (no admin dashboard).
- ~~Pulse: scale configurable, org-wide only, one active at a time, no comment field, no scheduling.~~ — Engagement domain cancelled for POC.
- Recognition: plain text, no values tagging. Leaderboard = 7d only.
- Auth: skipped — cookie-backed user picker.
- Avatars: deterministic initials, no upload.
- Translation: real via `ash_ai`, no stub.
- Search: per-resource `:search` action with `contains/2` + pg_trgm GIN index.
- Realtime: `AshTypescript.TypedChannel` for chat (per-conversation + per-user) and feed (org/venue). No pulse events on the `org:*` channel.

---

## 6. Next iterations of this plan

- **Section 7: Actions & validations per resource** — below.
- **Section 8: Frontend surface map** — pages, components, routes, the AshTypescript actions each one needs.
- **Section 9: Work split for parallel agents** — independent slices (each ~one domain + its UI) plus shared foundation work (auth, layout, seeds).
- **Section 10: Milestones & demo script** — minimum demo-able set, then polish items.

---

## 7. Actions, validations & policies per resource

### Conventions (apply unless stated)

- Every non-`Organization` resource carries `organization_id` and uses Ash's `:attribute` multitenancy mechanism for the auto-filter (see §4.1 for why we don't call it real multi-tenancy). Policies don't need to repeat the org-scope check.
- The cookie-backed user picker sets `actor: current_user` on every Ash call. `actor: nil` ⇒ unauthenticated.
- Role helpers on the actor: `admin?/1`, `manager?/1`, `staff?/1`. Default check `actor != nil and actor.organization_id == record.organization_id`.
- DB-level constraints (`check_constraint`, partial unique indexes) match every Ash validation that can be enforced at the DB level (per project rule).
- Actions that don't appear below are **not exposed** — no update, no destroy on most resources.
- Each public action gets a corresponding code-interface entry on its domain and (where the frontend needs it) an `rpc_action` entry for AshTypescript codegen.

---

### 7.1 Accounts

#### `Organization`
- **Actions:** `:read` only.
- **Policies:** `actor.organization_id == record.id`. Users only see their own org.
- **Creation:** seeded.

#### `User`
- **Actions:**
  - `:read` — list/get users in the actor's org. Used by the user-picker, shoutout recipient picker, post author display.
- **Policies:** signed-in user in the same org.
- **Creation / update:** seeded. No public actions.
- **Calculations:**
  - `birthday_today? :: :boolean` — `extract(month from birthday) == extract(month from now()) AND extract(day from birthday) == extract(day from now())`.

---

### 7.2 Venues

#### `Venue`
- **Actions:** `:read`.
- **Policies:** any signed-in user in the org.
- **Creation:** seeded.
- **DB constraints:** unique `(organization_id, slug)`.

#### `VenueMembership`
- **Actions:** `:read`.
- **Policies:** any signed-in user in the org (users need to see who works where for the people directory).
- **Creation / destroy:** seeded.
- **DB constraints:** unique `(user_id, venue_id)`.
- **After-action hook on create:** sync — add `ConversationMembership` for this user to the venue's `:venue_channel`.
- **After-action hook on destroy:** sync — remove that `ConversationMembership`.

---

### 7.3 Shifts

#### `Shift`
- **Actions:** `:read`.
- **Policies:** any signed-in user in the org (everyone can see the schedule for venues they belong to; frontend filters by their VenueMembership).
- **Creation:** seeded.
- **Validations:** `ends_at > starts_at`.
- **DB constraints:** `check_constraint :ends_after_starts, "ends_at > starts_at"`.

#### `ShiftAssignment`
- **Actions:** `:read`.
- **Policies:** any signed-in user in the org.
- **Creation / destroy:** seeded.
- **Validations:** the user must have a `VenueMembership` for `shift.venue_id` — checked in the (seed-only) create action.
- **DB constraints:** unique `(shift_id, user_id)`.
- **After-action hook on create:** sync — add `ConversationMembership` to the shift's `:shift_channel`.
- **After-action hook on destroy:** sync — remove that membership.

---

### 7.4 Feed

#### `Post`
- **Actions:**
  - `:read` — visibility-scoped (see policies).
  - `:create` — `accept [:title, :body, :original_locale, :auto_translate, :requires_acknowledgement, :venue_id]`. Author = actor. `published_at = now()`.
  - `:search` — argument `:query, :ci_string`, filter `expr(contains(title, ^arg(:query)) or contains(body, ^arg(:query)))`, offset pagination, default limit 12.
- **No update, no destroy** — posts are immutable.
- **Policies:**
  - read: `actor in org` AND (`venue_id IS NULL` OR `actor` has `VenueMembership` for `venue_id`).
  - create org-wide (`venue_id IS NULL`): `admin?(actor)`.
  - create venue-scoped: `admin?(actor)` OR (`manager?(actor)` AND `actor` has `VenueMembership` for `venue_id`).
- **DB constraints:** `pg_trgm` GIN indexes on `title` and `body`.
- **PubSub publications** (for live feed):
  - `publish :create, [:id], event: "post_created", public?: true, transform: :feed_summary` — calculation returns `%{id, title, venue_id, author_id, published_at}`.

#### `PostTranslation`
- **Actions:**
  - `:read` — any user who can read the post.
  - `:translate` — prompt-backed action (see §4.2). Returns `%TranslatedPost{title, body}`. Internal, called only by `:ensure_for`.
  - `:ensure_for` — cache-aware create. Arguments: `post_id`, `target_locale`. Looks up existing row → returns it; otherwise loads post, runs `:translate`, persists.
- **Policies:**
  - read: inherits from `Post`.
  - `:ensure_for`: any reader who can read the post.
  - `:translate`: no policy gate. The action is only called from inside `:ensure_for` with `authorize?: false`; never exposed via RPC or code interface.
- **DB constraints:** unique `(post_id, target_locale)`.

#### `Acknowledgement`
- **Actions:**
  - `:read`.
  - `:create` — `accept [:post_id]`. `user_id = actor.id`. Idempotent: rely on the unique index, treat duplicate inserts as success.
- **No destroy** — can't un-ack.
- **Policies:**
  - read: anyone who can read the post.
  - create: anyone who can read the post.
- **DB constraints:** unique `(post_id, user_id)`.
- **Aggregates on `Post`:**
  - `ack_count` — `count(acknowledgements)`.
  - `acknowledged_by_actor? :: :boolean` calculation (loaded per request) — checks for an Ack by the current actor.
- **PubSub:** `publish :create, [:post_id], event: "acknowledgement_added", transform: :ack_summary`.

---

### 7.5 Recognition

#### `Shoutout`
- **Actions:**
  - `:read`.
  - `:create` — `accept [:recipient_id, :body]`. `sender_id = actor.id`. `published_at = now()`.
  - `:search` — same shape as `Post.:search`, filters `contains(body, ^arg(:query))`.
  - `:top_recipients_this_week` — read action with no arguments; filters `published_at >= 7 days ago`, groups by `recipient_id`, orders by count desc, limit 5. (Implementation may use `Ash.Query.aggregate` or a custom prepare.)
- **No update, no destroy.**
- **Policies:**
  - read: any signed-in user in the org.
  - create: any signed-in user in the org. Sender ≠ recipient.
- **Validations:** `sender_id != recipient_id`. Recipient must be in the same org (the FK + auto-filter guarantees it, but validate explicitly to give a clearer error).
- **DB constraints:** `check_constraint :no_self_shoutout, "sender_id <> recipient_id"`. `pg_trgm` GIN on `body`.
- **PubSub:** `publish :create, [:id], event: "shoutout_created", transform: :shoutout_summary`.

---

### 7.6 Engagement — **CANCELLED for POC**

> **Status: cancelled.** No actions, policies, or constraints in §7.6 are to be implemented. The spec is preserved for revival.

#### `PulseSurvey`
- **Actions:**
  - `:read`.
  - `:create` — `accept [:prompt, :scale_min, :scale_max, :closes_at]`. Precondition: no row exists for this org with `closes_at > now()`.
- **No update, no destroy** — surveys close automatically when `now() >= closes_at`. History is preserved.
- **Policies:** _skipped for POC_ — any actor in the org can read and create. The org-scope FK still keeps orgs separate.
- **Validations:** `scale_max > scale_min`. `closes_at > now()` at create time.
- **DB constraints:** `check_constraint :scale_range, "scale_max > scale_min"`. `check_constraint :closes_in_future, "closes_at > inserted_at"`.
- **Calculations:** `active? :: :boolean` — `now() < closes_at`.
- **Aggregates** (used by admin view):
  - `response_count`, `average_score`, `score_distribution` (calculation returning a map).

#### `PulseResponse`
- **Actions:**
  - `:read`.
  - `:create` — `accept [:pulse_survey_id, :score]`. `user_id = actor.id`. Validates `score in [survey.scale_min, survey.scale_max]` AND `survey.active?`.
- **No update, no destroy** — one-shot.
- **Policies:** _skipped for POC_ — any actor in the org can read and create. One per `(survey, user)` is enforced by the unique constraint, not policy.
- **DB constraints:** unique `(pulse_survey_id, user_id)`.
- **PubSub**: `publish :create, [:organization_id], event: "pulse_response_recorded", transform: :pulse_aggregate` — broadcasts on `org:#{organization_id}` so the same channel handles every feed event. Payload is the aggregate snapshot, not the individual score.

---

### 7.7 Chat

#### `Conversation`
- **Actions:**
  - `:read` — only conversations the actor is a member of.
- **Creation:** not exposed publicly. Two internal create actions:
  - `:create_venue_channel` — called from `Venue` after-create hook. Arguments: `venue_id`. Sets `kind: :venue_channel`, `title: venue.name`.
  - `:create_shift_channel` — called from `Shift` after-create hook. Arguments: `shift_id`. Sets `kind: :shift_channel`, `venue_id: shift.venue_id`, `shift_id: shift.id`, `title: shift.name`.
- **No update, no destroy** publicly.
- **Policies:**
  - read: `exists membership where conversation_id == this.id and user_id == actor.id`.
  - create-anything: internal only (`AshAi.Checks.ActorIsAshAi`-style bypass).
- **DB constraints:** partial unique `(venue_id) WHERE kind = 'venue_channel'`; partial unique `(shift_id) WHERE kind = 'shift_channel'`.

#### `ConversationMembership`
- **Actions:**
  - `:read` — actor's own memberships.
  - `:mark_read` — update action. Argument: none (operates on the membership for `(conversation_id, actor.id)`). Sets `last_read_at = now()`.
- **Creation / destroy:** internal only (sync hooks from VenueMembership / ShiftAssignment).
- **Policies:**
  - read: `user_id == actor.id`.
  - `:mark_read`: `user_id == actor.id`.
- **DB constraints:** unique `(conversation_id, user_id)`.
- **After-action on `:mark_read`:** broadcast `unread_changed` on `user:#{actor.id}`.

#### `Message`
- **Actions:**
  - `:read` — only messages in conversations the actor is a member of.
  - `:create` — `accept [:conversation_id, :body]`. `author_id = actor.id`. Validates non-empty `body`.
- **No update, no destroy** — immutable.
- **Policies:**
  - read: `exists membership for (conversation_id, actor.id)`.
  - create: `exists membership for (conversation_id, actor.id)`.
- **PubSub publications:**
  - `publish :create, [:conversation_id], event: "message_created", topic: "chat:conversation:{conversation_id}", public?: true, transform: :message_summary`.
  - **Also** publish `unread_changed` on each non-author member's `user:#{user_id}` channel (via a notifier — not a single publication, since topic depends on each recipient).

---

### Side-effect summary

The following hooks/notifiers are non-trivial and worth flagging:

| Trigger | Effect |
|---|---|
| `Venue` create | `Conversation.create_venue_channel(venue_id)` |
| `Shift` create | `Conversation.create_shift_channel(shift_id)` |
| `VenueMembership` create | `ConversationMembership` create on the matching venue channel |
| `VenueMembership` destroy | matching `ConversationMembership` destroy |
| `ShiftAssignment` create | `ConversationMembership` create on the matching shift channel |
| `ShiftAssignment` destroy | matching `ConversationMembership` destroy |
| `Message` create | broadcast `unread_changed` to every non-author member's `user:*` channel |
| `ConversationMembership.mark_read` | broadcast `unread_changed` to actor's `user:*` channel |

All sync hooks are implemented as Ash `change after_action` or Ash notifiers — never as DB triggers.

### Derived read actions for the frontend

A handful of read actions exist purely to power specific frontend surfaces. They're all standard `read` actions with arguments, filters, and code-interface entries — each slice owner adds them alongside its resource.

| Action | On | Shape | Used by |
|---|---|---|---|
| `Accounts.User.celebrating_today` | `User` | filter `birthday_today? or work_anniversary_today?`; returns users | `<FeedPage>` (celebration cards) |
| ~~`Engagement.PulseSurvey.active`~~ | ~~`PulseSurvey`~~ | ~~filter `closes_at > now()`; limit 1~~ | ~~`<FeedPage>` (active pulse card), `<PulseAdminPage>`~~ — **CANCELLED** |
| ~~`Engagement.PulseSurvey.aggregate`~~ | ~~`PulseSurvey`~~ | ~~read by id, load `response_count` + `average_score` + `score_distribution` calc~~ | ~~`<PulseAdminPage>`~~ — **CANCELLED** |
| `Recognition.Shoutout.top_recipients_this_week` | `Shoutout` | already specified in §7.5 | `<LeaderboardPanel>` |
| `Chat.Conversation.list_for_actor` | `Conversation` | the default `:read` action already filters via the membership policy; expose with a code-interface alias `list_for_actor` for clarity | `<ConversationSidebar>` |
| `Chat.Message.list_for_conversation` | `Message` | argument `:conversation_id`; filter + limit; sort `inserted_at` desc | `<ConversationView>` |
| `Chat.ConversationMembership.unread_counts` | `ConversationMembership` | actor-scoped read returning `[{conversation_id, count}]`; count derived from messages where `inserted_at > last_read_at` | `<ConversationSidebar>` badges |
| `Feed.Post.validate_create` | `Post` | the auto-generated AshTypescript validation companion — no extra resource code | `<PostForm>` (per-blur validation) |
| `Feed.list_items` | _domain function_ | merges posts + shoutouts + celebrations, sorted by timestamp | `<FeedPage>` |

These don't need separate sections in §7 — they're conventional reads. The list exists so slice owners know exactly which RPCs to expose to satisfy the frontend in §8.

---

## 8. Frontend surface map

### 8.1 Shell setup

| Concern | Choice | Why |
|---|---|---|
| Routing | **React Router v6** | Standard SPA routing. Nested routes for `/chat/*`. |
| Data layer | **TanStack Query** wrapping `ash_rpc.ts` functions | AshTypescript explicitly leaves caching to the user; its generated functions return plain promises that slot into `queryFn` / `mutationFn` with zero adapter. |
| Forms | **React Hook Form + zod** | AshTypescript's own form-validation guide recommends this. The `validate*` action runs as a second server-side check after the zod schema passes. |
| UI primitives | **daisyUI** (already wired) + raw Tailwind | Card, btn, drawer, modal, tabs — all pre-styled. Custom CSS only for spacing. |
| Realtime | **`AshTypescript.TypedChannel`** generated client | Bridges channel events into TanStack Query via `queryClient.setQueryData` / `invalidateQueries`. |

**Conventions:**
- One `useXxx` hook per RPC action, colocated with the page that uses it most. Hooks live under `assets/js/hooks/`.
- Query keys are tuples: `["posts", { venueId }]`, `["conversations", "list"]`, `["unread", conversationId]`.
- All RPC calls include `headers: buildCSRFHeaders()` (already implemented in `ash_rpc.ts`).
- The `current_user` is loaded once at app boot via `loadCurrentUser()` (an RPC reading the cookie-backed user) and stored in React context — used by every component for role gating + initial channel joins.

---

### 8.2 Routes

| Path | Component | Role gate |
|---|---|---|
| `/` | `<FeedPage>` | any |
| `/posts/new` | `<PostComposePage>` | `admin` or `manager` (`manager` can pick venue) |
| `/search?q=` | `<SearchPage>` | any |
| ~~`/admin/pulse`~~ | ~~`<PulseAdminPage>`~~ | **CANCELLED** — Engagement out of scope |
| `/chat` | `<ChatLayout>` → redirect to first conversation | any |
| `/chat/:conversationId` | `<ChatLayout>` → `<ConversationView>` | any (membership-checked server-side) |

Role gates are component-level (render a "not authorized" placeholder rather than redirecting) and don't replace server-side policies — they're UX, not security.

---

### 8.3 Layout

```
┌─────────────────────────────────────────────────────────────┐
│  TopBar                                                      │
│  ┌──────────────┐  Feed | Chat | Search                       │
│  │ org name     │                              [UserPicker] │
│  └──────────────┘                                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│                   <Outlet />  (route content)                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**`<TopBar>`** — sticky, persistent.
- Org name + logo placeholder (left).
- Nav links: Feed / Chat / Search. (The Admin link was originally planned for `/admin/pulse`; cancelled along with Engagement.)
- `<UserPicker>` on the right — dropdown listing all seeded users. Selecting one writes `_crew_poc_user_id` directly to `document.cookie` and hard-refreshes. No server endpoint needed.

**`<ChatLayout>`** is a nested layout for `/chat/*` only:

```
┌──────────────┬───────────────────────────────────────────────┐
│ Sidebar      │  ConversationView                              │
│              │  ┌─────────────────────────────────────────┐  │
│ ─ Venue ch.  │  │  message list (scroll)                  │  │
│ ─ Venue ch.  │  │                                          │  │
│ ─ Shift ch.  │  │                                          │  │
│   (3)        │  └─────────────────────────────────────────┘  │
│ ─ Shift ch.  │  ┌─────────────────────────────────────────┐  │
│              │  │  composer                                │  │
└──────────────┴──┴─────────────────────────────────────────┘  ┘
```

Sidebar shows conversations the user is a member of. Unread badges from the `user:*` channel.

---

### 8.4 Page surfaces

For each page: components rendered, RPC actions called, realtime subscriptions.

#### `<FeedPage>` (`/`)

| Element | What it does |
|---|---|
| Components | `<ComposeButton>` (admin/manager only), `<FeedStream>` rendering `<PostCard>` / `<ShoutoutCard>` / `<CelebrationCard>` / `<LeaderboardPanel>` (sidebar). ~~`<ActivePulseCard>`~~ — cancelled. |
| RPC reads | `Feed.list_items(limit, offset)` (paginated merged stream), `Recognition.top_recipients_this_week`, `Accounts.todays_celebrations`. ~~`Engagement.active_survey`~~ — cancelled. |
| RPC mutations | `Acknowledgement.create(post_id)`, `Shoutout.create(...)` from a quick-shoutout modal. ~~`PulseResponse.create(survey_id, score)`~~ — cancelled. |
| Realtime | Joins `org:#{org_id}` typed channel; events `post_created`, `acknowledgement_added`, `shoutout_created` each invalidate the relevant query keys. ~~`pulse_response_recorded`~~ — cancelled. |
| Translation | On render, `<PostCard>` calls `Feed.ensure_translation(post_id, locale)` if `auto_translate && reader.locale != original_locale`. Suspense-friendly. |

#### `<PostComposePage>` (`/posts/new`)

| Element | What it does |
|---|---|
| Components | `<PostForm>` (react-hook-form + zod schema mirroring `Post.:create` accept list) |
| RPC | `Post.validate_create(...)` on blur of any field, then `Post.create(...)` on submit |
| Fields | title, body, venue_id (null = org-wide), auto_translate (checkbox), requires_acknowledgement (checkbox) |
| Post-submit | Navigate to `/`, optimistic insert into feed query cache |

#### `<SearchPage>` (`/search?q=`)

| Element | What it does |
|---|---|
| Components | `<SearchInput>` (debounced 250ms, syncs to URL `?q=`), `<SearchResults>` tabbed by kind (`All` / `Announcements` / `Shoutouts`) |
| RPC | `Search.global(query)` — backend fans out to `Feed.search_posts` + `Recognition.search_shoutouts` and merges by `inserted_at` |
| Realtime | None |

#### ~~`<PulseAdminPage>` (`/admin/pulse`)~~ — **CANCELLED**

> Page, components, hooks and the `org:*` pulse subscription below are all out of scope for the POC. Preserved for future revival.

| Element | What it does |
|---|---|
| Components | ~~`<ActiveSurveyForm>` (when no active survey, show creation form), `<ActiveSurveyResults>` (when one exists: prompt + aggregate + distribution chart), `<PastSurveys>` (list of closed)~~ |
| RPC | ~~`PulseSurvey.list`, `PulseSurvey.create`, `PulseSurvey.aggregate(survey_id)`~~ |
| Realtime | ~~Joins `org:#{org_id}`; `pulse_response_recorded` invalidates the active-survey aggregate query~~ |
| Charting | ~~Single `<DistributionBars>` — daisyUI progress bars rendered per score bucket. No chart library.~~ |

#### `<ChatLayout>` + `<ConversationView>` (`/chat/:conversationId`)

| Element | What it does |
|---|---|
| Components | `<ConversationSidebar>` (lists user's memberships with unread badges, grouped by venue/shift), `<ConversationHeader>` (title + member count), `<MessageList>` (virtualized? — no, basic flex column is fine at POC scale), `<MessageComposer>` |
| RPC reads | `Chat.list_my_conversations` (sidebar), `Chat.list_messages(conversation_id, limit)` (active conversation), `Chat.unread_counts` (initial badge state) |
| RPC mutations | `Message.create(conversation_id, body)`, `ConversationMembership.mark_read(conversation_id)` (fires on conversation open + after sending) |
| Realtime joined at layout mount | `user:#{actor.id}` — handles `unread_changed`, updates sidebar badges |
| Realtime joined per conversation | `chat:conversation:#{conversationId}` — handles `message_created`, appends to message list + scrolls if at bottom |

---

### 8.5 Shared components inventory

| Component | Used by | Notes |
|---|---|---|
| `<UserAvatar user={u} size />` | everywhere | Initials + `hsl(hash(u.id), 65%, 55%)` color. ~20 LOC. |
| `<UserPicker>` | TopBar | Lists seeded users, switches cookie, reloads. |
| `<UserLink user={u} />` | feed cards, message list | Avatar + name; clickable to people directory (out of scope; no-op for POC) |
| `<PostCard post />` | feed | Title, body (translated if applicable), author, timestamp, ack button + count |
| `<ShoutoutCard shoutout />` | feed | "X gave a shoutout to Y" framing, body, timestamp |
| `<CelebrationCard user kind />` | feed | "🎂 Anna turns N today" / "🎉 Pedro celebrates N years" |
| `<AckButton post />` | PostCard | Disabled when already acked; shows count inline |
| `<TranslateToggle />` | PostForm | Checkbox in compose form |
| ~~`<ActivePulseCard survey />`~~ | ~~FeedPage~~ | **CANCELLED** — Engagement out of scope |
| `<LeaderboardPanel />` | FeedPage (sidebar) | Top-5 recipients this week |
| `<MessageBubble message me />` | MessageList | daisyUI `chat` component variants |
| `<MessageComposer onSend />` | ChatLayout | Textarea + send button; Enter submits, Shift+Enter newline |
| `<UnreadBadge count />` | ConversationSidebar | Pill with the count, hidden when 0 |
| `<NotAuthorizedPlaceholder />` | role-gated pages | "Ask an admin to give you access." |

---

### 8.6 Data layer pattern (worked example)

One hook per action, query-key tuple convention. Channel events bridge into the cache.

```ts
// hooks/use-feed.ts
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { listFeedItems } from "../ash_rpc";
import { buildCSRFHeaders } from "../ash_rpc";

export const feedKey = (opts: { venueId?: string }) => ["feed", opts] as const;

export function useFeed(opts: { venueId?: string } = {}) {
  return useQuery({
    queryKey: feedKey(opts),
    queryFn: async () => {
      const r = await listFeedItems({ input: opts, headers: buildCSRFHeaders() });
      if (!r.success) throw new Error(r.errors[0].message);
      return r.data;
    },
  });
}

// app boot — bridge channel events into the cache
import { createOrgChannel, onOrgChannelMessages } from "../ash_typed_channels";

const channel = createOrgChannel(socket, currentUser.organizationId);
channel.join();

const queryClient = /* ... */;
onOrgChannelMessages(channel, {
  post_created: () => queryClient.invalidateQueries({ queryKey: ["feed"] }),
  shoutout_created: () => queryClient.invalidateQueries({ queryKey: ["feed"] }),
  acknowledgement_added: (payload) => {
    // optimistic: bump the ack count on the matching PostCard
    queryClient.setQueryData(["feed"], (old) => bumpAck(old, payload));
  },
  // pulse_response_recorded handler removed — Engagement is cancelled for the POC.
});
```

Mutations follow the same shape with `useMutation` + optimistic `setQueryData`.

---

### 8.7 Channel client wiring (summary)

| Channel | Joined when | Events handled |
|---|---|---|
| `org:#{org_id}` | App boot, after `current_user` loads | `post_created`, `acknowledgement_added`, `shoutout_created`. (~~`pulse_response_recorded`~~ — cancelled with Engagement.) |
| `user:#{user_id}` | App boot, after `current_user` loads | `unread_changed` → updates `<UnreadBadge>` per conversation |
| `chat:conversation:#{id}` | `<ConversationView>` mounts; left when unmounts | `message_created`, `read_advanced` |

All three channel clients are generated by `AshTypescript.TypedChannel` codegen — we never type a payload by hand.

---

## 9. Work split for parallel agents

Three phases. Phase 1 is sequential; Phase 2 fans out into two independent vertical slices (originally three — Slice C / Engagement is cancelled); Phase 3 stitches everything together.

```
┌─────────────────────────────────────────┐
│  Phase 1 — Foundation (sequential)       │
│  deps · Accounts · Venues · auth shell · │
│  frontend shell · minimal seeds          │
└────────────────┬────────────────────────┘
                 │
   ┌─────────────┼─────────────┐
   ▼             ▼             ▼ (cancelled)
┌──────┐    ┌──────┐    ┌────────────┐
│ A    │    │ B    │    │ ~~C~~      │  ◄─── Phase 2 (parallel)
│ Feed │    │ Chat │    │ Engagement │
└──┬───┘    └──┬───┘    └─────┬──────┘
   │           │              :
   └───────────┘              (out of scope)
               ▼
┌─────────────────────────────────────────┐
│  Phase 3 — Integration                   │
│  full seeds · translation E2E · polish · │
│  precommit · demo script                 │
└─────────────────────────────────────────┘
```

### 9.1 Phase 1 — Foundation (single agent, sequential)

Everything downstream assumes this is done. Don't fan out before it's green.

**Backend**
1. Install deps via igniter: `ash_postgres`, `ash_phoenix`, `ash_typescript`, `ash_ai`. Run `mix igniter.install ash_ai` so prompt-backed actions are wired.
2. Configure `Repo.installed_extensions/0` to include `["ash-functions", "pg_trgm"]`. Run `mix ash.setup`.
3. Configure ReqLLM in `runtime.exs` with `OPENROUTER_API_KEY`.
4. **Accounts domain**: `Organization` (id, name, slug, timestamps), `User` (all fields per §3.1). Code interface + RPC actions for `User.list` and `User.get`.
5. **Venues domain**: `Venue`, `VenueMembership` per §3.2. Code interface + RPC for `Venue.list` and `VenueMembership.list_for_user`. **Stub the after-action hook** (`Venue.create` → `Conversation.create_venue_channel`) to a no-op for now — Slice B will replace it.
6. `CrewPocWeb.Plugs.CurrentUser` — reads `_crew_poc_user_id` cookie, loads `User` by id, sets `conn.assigns.current_user`. Add to browser pipeline.
7. **Minimal seed**: 1 org, 5 users (mixed roles + locales fi/pt/es), 2 venues, all 5 users assigned to venue 1 and 2 users also to venue 2.

**Frontend**
10. Install: `react-router-dom`, `@tanstack/react-query`, `react-hook-form`, `zod`, `@hookform/resolvers`.
11. App shell: `<BrowserRouter>`, `<QueryClientProvider>`, layout with `<TopBar>` + `<Outlet>`.
12. `<UserPicker>` — fetches `User.list`, dropdown, hard-reloads on switch.
13. `<UserAvatar>` — initials + hash-derived color.
14. `useCurrentUser` hook — reads `current_user` from a bootstrap RPC on app load, stored in context.
15. **One placeholder route**: `/` renders "Logged in as: {currentUser.name}" so we can manually verify the cookie + RPC + frontend pipeline before fanning out.

**Definition of done**
- `mix precommit` green.
- Can switch between seeded users via `<UserPicker>` and see the right name on `/`.
- An RPC call from the frontend resolves with the correct `current_user` actor.

---

### 9.2 Phase 2 — Parallel slices

Each slice is end-to-end: domain + actions + frontend. Slices don't import from each other's frontend code; they touch each other's backend only via documented integration points (the side-effect hooks from §7).

#### Slice A — Alignment & Feed

| | |
|---|---|
| Owner agent | one |
| Depends on | Phase 1 complete |
| Other slices that depend on this | Phase 3 seeds expect Feed + Recognition |

**Backend**
- **Feed domain**: `Post`, `PostTranslation` (with the prompt-backed `:translate` action per §4.2), `Acknowledgement`. All actions per §7.4. `pg_trgm` GIN indexes on `Post.title` + `Post.body`.
- **Recognition domain**: `Shoutout` per §7.5. `pg_trgm` GIN on `Shoutout.body`. `top_recipients_this_week` read action.
- **Search**: `CrewPoc.Search.global/2` aggregator that calls `Feed.search_posts!` + `Recognition.search_shoutouts!`.
- **Celebration calculations on `User`**: `birthday_today?`, `work_anniversary_today?` (per §7.1) — they live on User but Slice A owns surfacing them.
- **`Feed.list_items`** domain function returning the merged-stream union (posts + shoutouts + celebrations) sorted by timestamp.
- **PubSub publications**: `post_created`, `shoutout_created`, `acknowledgement_added` (per §7.4 / §7.5).
- **TypedChannel module**: `CrewPocWeb.OrgFeedChannel` with topic `"org:*"`, subscribing to the three events above. Add to `:typed_channels` config.

**Frontend**
- Pages: `<FeedPage>` (`/`), `<PostComposePage>` (`/posts/new`), `<SearchPage>` (`/search`).
- Components: `<PostCard>`, `<ShoutoutCard>`, `<CelebrationCard>`, `<AckButton>`, `<LeaderboardPanel>`, `<TranslateToggle>`, `<SearchInput>`, `<SearchResults>`, `<ComposeButton>`, `<PostForm>` (react-hook-form + zod).
- Hooks: `useFeed`, `usePostMutation`, `useAckMutation`, `useShoutoutMutation`, `useSearch`, `useLeaderboard`, `useCelebrations`.
- Channel wiring: `org:#{org_id}` joined at app boot in a shared module — Slice A owns it. (Originally Slice C would extend it with `pulse_response_recorded`; cancelled.)

**Definition of done**
- Compose a post, see it appear in the feed live (without refresh) for another seeded user logged in another browser/profile.
- Ack a post, see the count tick live for other users.
- Send a shoutout, see it appear in the feed + leaderboard.
- Search returns matching posts and shoutouts.
- A post with `auto_translate: true` written in `:fi` displays translated body+title for an `:es` reader (via real OpenRouter call).
- Today's birthday/anniversary users appear as celebration cards.

---

#### Slice B — Chat

| | |
|---|---|
| Owner agent | one |
| Depends on | Phase 1 complete + Slice A's `org:*` channel module (just to share the socket; not blocking) |

**Backend**
- **Shifts domain**: `Shift`, `ShiftAssignment` per §7.3. Validation + DB check constraint on `ends_at > starts_at`. Validation that ShiftAssignment user must already have VenueMembership.
- **Chat domain**: `Conversation`, `ConversationMembership`, `Message` per §7.7.
- **Sync hooks** (replace the Phase-1 stubs):
  - `Venue.create` after-action → `Conversation.create_venue_channel`.
  - `VenueMembership.create` / `:destroy` → add/remove `ConversationMembership` on the venue channel.
  - `Shift.create` after-action → `Conversation.create_shift_channel`.
  - `ShiftAssignment.create` / `:destroy` → add/remove `ConversationMembership` on the shift channel.
- **`Message.create`**: PubSub publishes `message_created` on `chat:conversation:#{conversation_id}`. Also broadcasts `unread_changed` to each non-author member's `user:#{user_id}` topic via a notifier.
- **`ConversationMembership.mark_read`**: update action; broadcasts `unread_changed` to actor's `user:*`.
- **One-time backfill** (run during Slice B activation, before the sync hooks become canonical): for every existing `VenueMembership` and `ShiftAssignment`, create the matching `Conversation` (if missing) and `ConversationMembership`. Otherwise users seeded in Phase 1 won't appear in their venue channels. Add as a mix task `mix crew_poc.sync_chat_memberships` so it's re-runnable and idempotent.
- **TypedChannel modules**:
  - `CrewPocWeb.ChatConversationChannel` topic `"chat:conversation:*"`, events `message_created`, `read_advanced`.
  - `CrewPocWeb.UserNotificationsChannel` topic `"user:*"`, event `unread_changed`.

**Frontend**
- Pages: `<ChatLayout>` at `/chat/*`, `<ConversationView>` at `/chat/:conversationId`.
- Components: `<ConversationSidebar>` (grouped: Venue / Shift), `<UnreadBadge>`, `<ConversationHeader>`, `<MessageList>`, `<MessageBubble>`, `<MessageComposer>`.
- Hooks: `useMyConversations`, `useMessages(conversationId)`, `useSendMessage`, `useMarkRead`, `useUnreadCounts`.
- Channel wiring:
  - `user:#{actor.id}` joined at chat layout mount (or app boot — owner's choice).
  - `chat:conversation:#{id}` joined per `<ConversationView>` mount; unsubscribed on unmount.
  - `message_created` → optimistic append to `useMessages` cache.
  - `unread_changed` → invalidate `useUnreadCounts`.

**Definition of done**
- Open `/chat/:id` for venue channel A as user 1; another browser as user 2 sends a message; user 1 sees it instantly.
- The sidebar badge for venue channel A on user 1's app updates to "1" when user 1 isn't actively viewing it.
- `mark_read` clears the badge.
- Adding a `VenueMembership` (in iex or seed) causes a new `ConversationMembership` to appear for that user.

---

#### ~~Slice C — Engagement~~ — **CANCELLED**

> **Status: cancelled.** Slice C is not part of the POC. No backend, frontend, or seed work for Engagement should be done. The block below is preserved verbatim for future revival. Slice A no longer ships an `<ActivePulseCard>` and Slice A's `org:*` channel module does not subscribe to `pulse_response_recorded`.

| | |
|---|---|
| Owner agent | one |
| Depends on | Phase 1 complete; reuses Slice A's `org:*` channel by adding a `pulse_response_recorded` publication |

**Backend**
- **Engagement domain**: `PulseSurvey`, `PulseResponse` per §7.6.
- `PulseSurvey.create` action with precondition: no existing survey with `closes_at > now()` in this org.
- `PulseResponse.create` action validating `score` against the survey's scale + `survey.active?`.
- `active? :: :boolean` calculation; aggregates `response_count`, `average_score`, `score_distribution`.
- **PubSub publication** on `Response.create` → `pulse_response_recorded` on `org:#{org_id}` (extends Slice A's channel; Slice C adds the publication, Slice A's channel module declares the subscription).

**Frontend**
- Page: `<PulseAdminPage>` (`/admin/pulse`).
- Components: `<ActiveSurveyForm>` (creation form, only when no active survey exists), `<ActiveSurveyResults>` (prompt + aggregate + `<DistributionBars>`), `<PastSurveys>` (collapsed list), `<ActivePulseCard>` (the one that lands on `<FeedPage>` — Slice C ships the component, Slice A consumes it from the feed).
- Hooks: `useActiveSurvey`, `useCreateSurvey`, `useSubmitResponse`, `useSurveyAggregate(id)`, `usePastSurveys`.
- Channel wiring: subscribe to `pulse_response_recorded` on the shared `org:*` channel → invalidates `useSurveyAggregate`.

**Definition of done**
- Create a survey on `/admin/pulse`.
- It appears as `<ActivePulseCard>` at the top of the feed for all users.
- Three users submit different scores → admin sees aggregate update live without refresh.
- After `closes_at`, the card disappears from the feed (only `active?` rows surfaced).
- A new survey can be created once the previous closes.

---

### 9.3 Phase 3 — Integration

Single agent again. Runs after all three slices are independently green.

**Tasks**
1. **Full seed file**: 1 org, 3 venues, 20 users (locales fi/pt/es, varied roles, mixed birthdays + started_at), 5 shifts with assignments, 10 announcements (mix of org-wide + venue-scoped, some `auto_translate: true`), 15 shoutouts (varied senders/recipients spread over the last 14 days for leaderboard variety). (Pulse surveys + responses removed — Engagement cancelled.)
2. **Translation smoke test**: pick one seeded `:fi` post with `auto_translate: true`, log in as a `:pt` user, verify a real OpenRouter call lands and is cached on the second view.
3. **Cross-slice scenarios**:
   - Adding a user to a venue (via iex) auto-joins them to that venue's chat channel — verify in two browsers.
   - Posting an announcement triggers `post_created` on `org:*` and updates every signed-in user's feed simultaneously.
   - ~~Submitting a pulse response updates the admin's aggregate live.~~ — cancelled.
4. **Polish pass**: empty states (no messages, no shoutouts), loading skeletons, error boundaries on each page.
5. **`mix precommit` green** end-to-end.
6. **Demo script** (becomes §10): 5-minute walkthrough hitting feed → shoutout → translation → leaderboard → chat.

---

### 9.4 Coordination contract

What slice agents must respect to avoid stepping on each other:

| Rule | Why |
|---|---|
| **The AshTypescript codegen is the seam.** Run `mix ash_typescript.codegen` immediately after adding a new `rpc_action` and commit the regenerated `ash_rpc.ts` / `ash_types.ts` / `ash_typed_channels.ts`. | Other slices need the type to import. |
| **Never hand-edit the generated files.** | They will be regenerated and your edit will vanish. |
| **The `org:*` channel module is shared.** Slice A creates it; Slices B/C extend it by adding their resource's `publish` to the `typed_channel do` block in `OrgFeedChannel`. | One channel module per topic, even though events come from multiple resources. |
| **Sync hooks (§7 side-effect table) belong to Slice B.** Slice A may leave Phase-1 stubs in place; B replaces them. | One owner for the cross-domain wiring keeps the graph clear. |
| **Don't depend on another slice's frontend hooks or components.** Re-implement or move shared bits to `assets/js/shared/`. | Frontend coupling is harder to refactor than backend. |
| **Migrations from each slice land in their own files via `mix ash_postgres.generate_migrations` after each resource change.** | Avoids merge conflicts on a single mega-migration. |

If two slices need the same shared component (e.g. `<UserAvatar>` is needed everywhere), it lives in `assets/js/shared/` and Phase 1 ships it.

---

### 9.5 Data setup pattern (seeders + generators)

Two distinct artifacts. The **seeder** populates dev/demo data through `priv/repo/seeds.exs`. The **generator** produces test fixtures via `Ash.Generator`. They share no code but follow the same shape rules.

#### `CrewPoc.Seeder` (dev / demo data)

Lives at `lib/crew_poc/seeder.ex`. One public function per resource, each returning a list of attribute maps. Hardcoded, realistic, hospitality-themed.

```elixir
defmodule CrewPoc.Seeder do
  @moduledoc """
  Hardcoded seed data for local development.
  Realistic Nordic hospitality data across organizations, venues, users,
  shifts, posts, and shoutouts. (Pulse surveys are out of scope for the POC.)
  """

  # Split verbose datasets into submodules when they get long.
  defdelegate posts, to: CrewPoc.Seeder.PostData, as: :all

  def organizations do
    [
      %{name: "Meridian Hotels & Resorts", slug: "meridian"}
    ]
  end

  def users do
    [
      %{
        email: "james.okafor@example.com",
        name: "James Okafor",
        role: :admin,
        locale: :es,
        job_title: "Regional Operations Director",
        birthday: ~D[1982-04-12],
        started_at: ~D[2016-03-01],
        organization_slug: "meridian"
      },
      %{
        email: "sofia.reyes@example.com",
        name: "Sofia Reyes",
        role: :manager,
        locale: :es,
        job_title: "Hotel General Manager",
        birthday: ~D[1988-09-25],
        started_at: ~D[2019-07-15],
        organization_slug: "meridian"
      }
      # ... 18 more
    ]
  end

  def venues do
    [
      %{slug: "london-mayfair", name: "Meridian Grand London", city: "London",
        timezone: "Europe/London", organization_slug: "meridian"},
      %{slug: "dubai-marina", name: "Meridian Dubai Marina", city: "Dubai",
        timezone: "Asia/Dubai", organization_slug: "meridian"},
      %{slug: "new-york-midtown", name: "Meridian New York Midtown", city: "New York",
        timezone: "America/New_York", organization_slug: "meridian"}
    ]
  end

  def venue_memberships do
    # Cross-reference by domain-meaningful keys — never UUIDs.
    [
      %{user_email: "james.okafor@example.com", venue_slug: "london-mayfair"},
      %{user_email: "sofia.reyes@example.com", venue_slug: "london-mayfair"},
      # ...
    ]
  end

  # shifts, shift_assignments, posts, shoutouts, messages ...
  # (pulse_survey + pulse_response intentionally omitted — Engagement cancelled.)
end
```

**Conventions**
- One public function per resource: zero-arity, returns a list of maps.
- **Cross-reference by domain-meaningful keys** — `organization_slug`, `user_email`, `venue_slug`, `shift_label`. Never UUIDs (uuids change on every seed run; slugs/emails stay stable for re-runs).
- Realistic content (multi-paragraph bodies for posts, mixed locales, varied roles). The demo's "wow" depends on this.
- Split a function into a submodule (`CrewPoc.Seeder.PostData`) when its data exceeds ~50 lines.

#### `priv/repo/seeds.exs` (the orchestration script)

The script is *not* data — it consumes `CrewPoc.Seeder` and resolves the cross-references. Standard shape:

```elixir
require Ash.Query
import Ecto.Query

alias CrewPoc.Repo
alias CrewPoc.Accounts.{Organization, User}
alias CrewPoc.Venues.{Venue, VenueMembership}
# ... aliases for every domain

# ── COLLECT KNOWN SEED IDENTIFIERS ────────────────────────────────────────────
org_slugs = Enum.map(CrewPoc.Seeder.organizations(), & &1.slug)
user_emails = Enum.map(CrewPoc.Seeder.users(), & &1.email)
venue_slugs = Enum.map(CrewPoc.Seeder.venues(), & &1.slug)
# ... etc

# ── CLEAN UP (reverse dependency order, filtered by seed identifiers) ──────────
# Use Ash.bulk_destroy! when a :destroy action exists; otherwise Repo.delete_all.
# Filtering by seed identifiers means the script is idempotent and never
# nukes data that wasn't seeded.

if Ash.Resource.Info.action(Message, :destroy) do
  Message
  |> Ash.Query.filter(conversation.venue.organization.slug in ^org_slugs)
  |> Ash.bulk_destroy!(:destroy, %{}, strategy: :stream, authorize?: false)
else
  # Ecto fallback — only when the resource has no destroy action exposed.
end

# ... destroy in reverse dep order: messages → conversation_memberships → conversations
# → acknowledgements → post_translations → posts → shoutouts → shift_assignments
# → shifts → venue_memberships → venues → users → organizations
# (pulse_responses + pulse_surveys removed from the chain — Engagement cancelled.)

IO.puts("Cleaned existing seed data")

# ── ORGANIZATIONS (Ash.bulk_create! when no cross-refs) ───────────────────────
Ash.bulk_create!(CrewPoc.Seeder.organizations(), Organization, :create,
  return_errors?: true, authorize?: false)

org_map =
  Organization
  |> Ash.Query.filter(slug in ^org_slugs)
  |> Ash.read!(authorize?: false)
  |> Map.new(&{&1.slug, &1.id})

IO.puts("Seeded #{map_size(org_map)} organizations")

# ── USERS (resolve organization_slug → organization_id) ───────────────────────
user_data =
  Enum.map(CrewPoc.Seeder.users(), fn u ->
    u
    |> Map.put(:organization_id, Map.fetch!(org_map, u.organization_slug))
    |> Map.drop([:organization_slug])
  end)

Ash.bulk_create!(user_data, User, :create, return_errors?: true, authorize?: false)

user_map =
  User
  |> Ash.Query.filter(email in ^user_emails)
  |> Ash.read!(authorize?: false)
  |> Map.new(&{&1.email, &1.id})

IO.puts("Seeded #{length(user_data)} users")

# ... and so on, building up a lookup map per resource, resolving FKs as we go.
```

**Rules**
- **Idempotent.** The clean-up phase filters by seed identifiers so re-running the seed never blows up unrelated data.
- **Topological order.** Create in dependency order (orgs → users → venues → memberships → shifts → assignments → posts → ...). Reverse for cleanup.
- **Prefer `Ash.bulk_create!`** over per-record creates — fewer DB roundtrips and one place for `return_errors?: true`.
- **Use `Ash.Seed.seed!`** when the resource has no public `:create` action exposed (e.g., system-created `Conversation` rows). It bypasses Ash validations and inserts directly — useful for fixture data we trust.
- **Resolve FKs by lookup map**, not by querying inside loops. Build the map once per resource right after creation.
- **`IO.puts` after each batch** so the seed log is human-readable when something goes wrong.

#### `CrewPoc.Generator` (test fixtures)

Lives at `test/support/generator.ex`. Uses `Ash.Generator`. One public function per resource, with `opts` overrides.

```elixir
defmodule CrewPoc.Generator do
  @moduledoc "Data generation for tests"
  use Ash.Generator

  defp uniq, do: System.unique_integer([:positive])

  #####################
  ### Organizations ###
  #####################

  def organization(opts \\ []) do
    changeset_generator(
      CrewPoc.Accounts.Organization,
      :create,
      defaults: [
        name: sequence(:org_name, &"Org #{&1}"),
        slug: sequence(:org_slug, &"org-#{uniq()}-#{&1}")
      ],
      overrides: opts,
      authorize?: false
    )
  end

  #############
  ### Users ###
  #############

  @doc """
  Generates user records.

  ## Extra Options
  - `:organization_id` - Required. Pass an existing org id or let it create one.
  - `:venues` - List of venue ids to auto-assign via VenueMembership.
  """
  def user(opts \\ []) do
    {venues, opts} = Keyword.pop(opts, :venues, [])

    organization_id =
      opts[:organization_id] ||
        once(:default_organization_id, fn -> (organization() |> generate()).id end)

    after_action =
      if venues != [] do
        &create_venue_memberships(&1, venues)
      end

    seed_generator(
      %CrewPoc.Accounts.User{
        email: sequence(:user_email, &"user#{uniq()}-#{&1}@example.com"),
        name: sequence(:user_name, &"User #{&1}"),
        role: :staff,
        locale: :fi,
        started_at: ~D[2024-01-01],
        organization_id: organization_id
      },
      overrides: opts,
      after_action: after_action
    )
  end

  defp create_venue_memberships(user, venue_ids) do
    for venue_id <- venue_ids do
      venue_membership(user_id: user.id, venue_id: venue_id) |> generate()
    end

    user
  end

  ##############
  ### Venues ###
  ##############

  def venue(opts \\ []) do
    organization_id =
      opts[:organization_id] ||
        once(:default_organization_id, fn -> (organization() |> generate()).id end)

    changeset_generator(
      CrewPoc.Venues.Venue,
      :create,
      defaults: [
        name: sequence(:venue_name, &"Venue #{&1}"),
        slug: sequence(:venue_slug, &"venue-#{uniq()}-#{&1}"),
        city: "Helsinki",
        timezone: "Europe/Helsinki",
        organization_id: organization_id
      ],
      overrides: opts,
      authorize?: false
    )
  end

  # venue_membership, shift, shift_assignment, post, acknowledgement, shoutout,
  # conversation, conversation_membership, message ...
  # (pulse_survey + pulse_response intentionally omitted — Engagement cancelled.)
end
```

**Conventions**
- **`changeset_generator`** = run the resource's `:create` (or other) action with full validation. Use this by default.
- **`seed_generator`** = bypass actions and insert directly. Use when:
  - The resource's create action has side effects you want to skip in tests (e.g., publishing PubSub, triggering hooks).
  - You want to set fields that aren't on the public `accept` list.
  - The resource has no usable create action (`Conversation`, `ConversationMembership` — system-only).
- **`sequence/2`** for unique fields (`email`, `slug`, `name`). Always include `&uniq()` in the format string for collision safety across tests.
- **`once/2`** for memoized defaults within a single test run (e.g., one default org reused across multiple `user()` calls). Each test process gets its own cache.
- **`after_action`** for post-create wiring (creating memberships, assignments, etc.).
- Section banners (`### Users ###`) keep the file scannable as resources accumulate.
- Generators are excluded from the Credo "pipe-chain must start with raw value" rule (per CLAUDE.md), so `user() |> generate()` style is fine.

#### How tests use generators

Per CLAUDE.md (already documented there):
```elixir
user = user() |> generate()
[admin, staff] = user() |> generate_many(2)
post = [author_id: admin.id, venue_id: venue.id] |> post() |> generate()
```

Setup blocks share fixtures across tests via context — see the `## Testing` section of CLAUDE.md for the full pattern.

#### Where this fits in the work split

- **Phase 1, step 9** — minimal seed:
  - Implement `CrewPoc.Seeder.organizations/0`, `users/0`, `venues/0`, `venue_memberships/0`.
  - Write the corresponding cleanup + create blocks in `priv/repo/seeds.exs`.
- **Phase 1, step 5–6** — generators for `Organization`, `User`, `Venue`, `VenueMembership` so the foundation tests can use them immediately.
- **Phase 2, each slice** — adds its own seeder functions + generators when introducing new resources.
- **Phase 3, task 1** — extends the seeder to full demo data (10 announcements, 15 shoutouts, etc.) and verifies `mix ecto.reset` produces a usable demo state.

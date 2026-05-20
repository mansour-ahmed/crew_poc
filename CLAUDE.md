This is a web application built with Phoenix and Ash.

## How to Update This File

- When I give corrective feedback, a preference, or say "always do X", "never do Y", "I prefer Z", "remember this" — treat it as a potential rule for this file
- At the end of the conversation (or when I run /update-agents), propose a concise one-line bullet to add here
- Show me the exact proposed addition and where it should go
- Only write to this file after I explicitly approve
- Format rules as imperative one-liners
- Check existing rules first to avoid duplicates — strengthen existing rules rather than adding redundant ones

## Ash First

Always use Ash concepts, almost never Ecto concepts directly. Think hard about the "Ash way" to do things. If you don't know, look for information in the rules & docs of Ash & associated packages.

## Project guidelines

- **Always** run `mix precommit` when you are done with all changes. It runs `compile --warnings-as-errors`, `deps.unlock --unused`, `format`, `credo --strict`, and `test` in sequence. Fix any issues before committing.
- Start with generators wherever possible. They provide a starting point for your code and can be modified if needed.
- When you're done executing code, try to compile the code, and check the logs or run any applicable tests to see what effect your changes have had.
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

## Code style

### Module structure

**Always** define highest-abstraction (public API) functions at the top of the module, followed by progressively lower-level helper functions toward the bottom. Readers should be able to scan a module top-down and understand _what_ it does before seeing _how_.

```elixir
defmodule CrewPoc.Shifts do
  # --- Public API (highest abstraction) ---

  def schedule_shift(venue, attrs) do
    with {:ok, shift} <- build_shift(venue, attrs),
         {:ok, shift} <- assign_crew(shift) do
      save(shift)
    end
  end

  # --- Mid-level helpers ---

  defp build_shift(venue, attrs) do
    # ...
  end

  defp assign_crew(shift) do
    # ...
  end

  # --- Low-level helpers ---

  defp save(shift) do
    # ...
  end
end
```

**Always** place `import`, `alias`, and `use` declarations at the top of the module. Never nest them inside functions or blocks.

```elixir
# Good
defmodule CrewPoc.Accounts do
  import Ecto.Query
  alias CrewPoc.Accounts.User

  def list_active do
    User |> where([u], u.active) |> Repo.all()
  end
end

# Bad — import nested inside a function
defmodule CrewPoc.Accounts do
  def list_active do
    import Ecto.Query
    CrewPoc.Accounts.User |> where([u], u.active) |> Repo.all()
  end
end
```

**Always** use `alias` when a module name is referenced more than once in a file. This applies to all modules, including framework modules like `Ash.Changeset`, `Ash.Query`, etc.:

```elixir
# Good
alias CrewPoc.Accounts.User
alias Ash.Changeset

def find(id), do: User.get(id)
def list, do: User.list_all()

def validate(changeset) do
  Changeset.get_attribute(changeset, :name)
  Changeset.get_attribute(changeset, :email)
end

# Bad — repeating the full module name
def find(id), do: CrewPoc.Accounts.User.get(id)
def list, do: CrewPoc.Accounts.User.list_all()

def validate(changeset) do
  Ash.Changeset.get_attribute(changeset, :name)
  Ash.Changeset.get_attribute(changeset, :email)
end
```

### Naming

**Always** use descriptive, full-word variable names. Avoid abbreviations of 1-2 letters. Clarity is more important than brevity:

```elixir
# Good
%{venue: venue, shift: shift, user: user, organization: organization}

# Bad — short abbreviations obscure meaning
%{venue: v, shift: sh, user: u, organization: o}
```

### Pattern matching

**Always** prefer struct pattern matches on function inputs when the type is known. This provides compile-time checks, clearer intent, and better documentation of expected types:

```elixir
# Good — struct types are explicit, list non-emptiness checked via pattern
def deliver_shifts_notification!(%User{} = user, [%Shift{} | _] = shifts) do
  # ...
end

def process_tags([%Tag{} | _] = tags) do
  # ...
end

# Bad — no type information, guard-based list check
def deliver_shifts_notification!(user, shifts) when is_list(shifts) and length(shifts) > 0 do
  # ...
end
```

**Always** prefer `[_ | _]` pattern matching to assert a non-empty list instead of `is_list(x) and length(x) > 0` guards. Use `[%Struct{} | _]` when the element type is known:

```elixir
# Good — pattern match for non-empty list
def notify_all([_ | _] = users), do: Enum.each(users, &notify/1)
def notify_all([]), do: :noop

# Good — pattern match with known struct type
def notify_all([%User{} | _] = users), do: Enum.each(users, &notify/1)

# Bad — verbose guard for the same check
def notify_all(users) when is_list(users) and length(users) > 0 do
  Enum.each(users, &notify/1)
end
```

**Always** use early-return pattern matches for invalid or no-op inputs (e.g. empty lists) before the main function clause. Guard on known types (e.g. `when is_binary(id)`) in all clauses:

```elixir
# Good — empty list short-circuits, guard validates input type
def perform(%Oban.Job{args: %{"user_id" => user_id, "item_ids" => []}})
    when is_binary(user_id) do
  Logger.info("Skipping, no items for #{user_id}")
  :ok
end

def perform(%Oban.Job{args: %{"user_id" => user_id, "item_ids" => item_ids}})
    when is_binary(user_id) do
  # main logic
end
```

### Ash patterns

**Always** add a matching `check_constraint` in the `postgres do` block for every Ash validation that can be enforced at the database level (numeric ranges, string lengths, date comparisons, enum values, conditional presence). This ensures data integrity even when bypassing actions (e.g. via `Ash.Seed.seed!`, raw SQL, or migrations). After adding constraints, run `mix ash_postgres.generate_migrations` to generate the migration:

```elixir
# In the resource — validation + matching DB constraint
validations do
  validate compare(:priority, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
end

postgres do
  check_constraints do
    check_constraint :priority, "priority_range",
      check: "priority >= 1 AND priority <= 10",
      message: "must be between 1 and 10"
  end
end
```

Test non-enum constraints with `Ash.Seed.seed!` (bypasses Ash validations, hits DB) and enum constraints with raw SQL via `CrewPoc.Repo.query` (Ash types reject invalid enums before reaching DB):

```elixir
describe "check constraints" do
  # Non-enum: Ash.Seed.seed! bypasses validations, DB constraint catches it
  test "given priority outside 1-10, the DB rejects it" do
    assert_raise Ash.Error.Invalid, ~r/must be between 1 and 10/, fn ->
      Ash.Seed.seed!(Tag, %{label: "X", value: "x", type: :skill, keywords: ["x"], priority: 0})
    end
  end

  # Enum: Ash types block invalid values, so test via raw SQL UPDATE
  test "given an invalid type at DB level, the constraint rejects it" do
    existing = tag() |> generate()

    assert {:error, %{postgres: %{constraint: "type_enum"}}} =
             CrewPoc.Repo.query("UPDATE tags SET type = 'invalid' WHERE id = '#{existing.id}'")
  end
end
```

**Prefer** `Ash.Changeset.change_attribute/3` over `Ash.Changeset.force_change_attribute/3`. Only use `force_change_attribute` when you need to bypass `accept` lists or set non-public attributes programmatically.

### Pipes & expressions

**Always** prefer `Enum.count/1` over `length/1` for counting list elements.

**Prefer** pipe chains over intermediate variable assignments. Transform sequential calls into pipelines where the data flows naturally as the first argument:

```elixir
# Good — pipe chain
type_atom
|> get_shift_data(url)
|> ShiftDataConverter.convert()
|> create_shift()

# Bad — intermediate variables
shift_data = get_shift_data(type_atom, url)
params = ShiftDataConverter.convert(shift_data)
create_shift(params)
```

**Prefer** the `do:` inline syntax for one-liner functions instead of `do...end` blocks. The same applies to `if/else` — use the comma-style `if ..., do: ..., else: ...` when each branch is a single expression:

```elixir
# Good
def active?(user), do: user.status == :active

defp full_name(user), do: "#{user.first_name} #{user.last_name}"

if opts[:start_field] && opts[:end_field],
  do: {:ok, opts},
  else: {:error, "start_field and end_field are required"}

# Bad — unnecessary verbosity for a single expression
def active?(user) do
  user.status == :active
end

if opts[:start_field] && opts[:end_field] do
  {:ok, opts}
else
  {:error, "start_field and end_field are required"}
end
```

## Credo (Static Analysis)

**Always** run `mix credo --strict` before committing. It is included in `mix precommit` alongside the formatter and tests. All code must pass with zero issues.

The project uses an extended Credo configuration (`.credo.exs`) with many checks enabled beyond defaults. Key rules enforced:

### Pipe chains

- **Pipe chains must start with a raw value or variable**, not a function call. Restructure so the first element in the pipe is a module, variable, or literal. **Exception**: test generator functions (`user`, `shift`, `tag`, `venue`, `organization`, `user_authorization`, `user_organization`, `shift_assignment`, `generate`, `generate_many`) are excluded from this rule and may start pipe chains:

```elixir
# Good — starts with a module (raw value)
User
|> Ash.Changeset.for_create(:register, %{email: email})
|> Ash.create!(authorize?: false)

# Good — generator functions are excluded, piping is fine
tag(type: :skill) |> generate()
user() |> generate()
[authorizations: [:scandic]] |> user() |> generate()

# Bad — starts with a non-excluded function call
Ash.Changeset.for_create(User, :register, %{email: email})
|> Ash.create!(authorize?: false)
```

- **One pipe per line.** Never chain multiple pipes on a single line:

```elixir
# Good
result
|> Enum.map(& &1.id)
|> assert_lists_equal(expected_ids)

# Bad — multiple pipes on one line
result |> Enum.map(& &1.id) |> assert_lists_equal(expected_ids)
```

- **No single-function-to-block pipes**. If a pipe chain ends with only one function call into a `do` block, use direct function call syntax instead.

### Aliases

- **Aliases must be in alphabetical order**.
- **Never use `:as` with alias**. Use the default short name:

```elixir
# Good
alias AshAuthentication.Info

Info.strategy!(User, :magic_link)

# Bad — unnecessary rename
alias AshAuthentication.Info, as: AuthInfo

AuthInfo.strategy!(User, :magic_link)
```

### Other enforced rules

- **Use `Enum.empty?/1`** instead of `Enum.count(list) == 0` for emptiness checks.
- **Use `Enum.map_join/3`** instead of `Enum.map/2 |> Enum.join/1`.
- **Avoid `Enum.map |> Enum.map`** — combine into a single `Enum.map`.
- **Use `~s` sigils** for strings containing double quotes instead of escaping.
- **Pass `async: true`** in all test module `use` declarations where possible.
- **Use parentheses on zero-arity def/defp** (`def foo()` not `def foo`).
- **Max line length is 120 characters**.
- **Avoid appending single items** — use `[item | list]` instead of `list ++ [item]`.
- **Keep nesting depth reasonable** — refactor deeply nested code into helper functions.

## Testing

### Test file location

Tests are **co-located** with the source file they test. Place test files next to the module they test:
- `lib/crew_poc/accounts/user.ex` → `lib/crew_poc/accounts/user_test.exs`
- `lib/crew_poc/accounts/user_authorization.ex` → `lib/crew_poc/accounts/user_authorization_test.exs`

### Test message format

**Always** use `"given <condition>, <expected outcome>"` for test descriptions:

    # Good
    test "given an admin actor, the authorization is created"
    test "given no user_id, a default user is created"
    test "given a duplicate user+type pair, an error is raised"

    # Bad
    test "the actor that created the record"
    test "can create authorization"

### Boilerplate

```elixir
defmodule CrewPoc.Accounts.UserAuthorizationTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Accounts, warn: false
end
```

### Data generation

**Always** use generators from `test/support/generator.ex`. Never manually build structs or insert records. **Prefer** piping when passing options to generators:

```elixir
user = user() |> generate()
user = [authorizations: [:scandic]] |> user() |> generate()
[user1, user2] = user() |> generate_many(2)
auth = [user_id: user.id, type: :hilton] |> user_authorization() |> generate()
```

### Use `@valid_attrs` module attribute for create action inputs

**Always** define a `@valid_attrs` module attribute containing valid create action inputs. This avoids repeating the same attribute map across create, validation, constraint, and policy tests. Use `%{@valid_attrs | key: val}` to override a single field, `Map.merge(@valid_attrs, %{...})` to add optional fields, and `Map.put(@valid_attrs, :key, val)` to add a new key:

```elixir
@valid_attrs %{
  name: "Hotel Helsinki Central",
  postal_code: "00100",
  city: "Helsinki",
  street_address: "Hotelinkatu 1",
  capacity: 120,
  rooms: 50,
  hourly_rate: 18.0
}

# Create test — pass directly
Venue
|> Ash.Changeset.for_create(:create, @valid_attrs)
|> Ash.create!(authorize?: false)

# Validation test — override the field being validated
Venue
|> Ash.Changeset.for_create(:create, %{@valid_attrs | capacity: 5})
|> Ash.create!(authorize?: false)

# Optional fields test — merge additional keys
Venue
|> Ash.Changeset.for_create(:create, Map.merge(@valid_attrs, %{category: :luxury, parking_fee: 25.0}))
|> Ash.create!(authorize?: false)

# Constraint test — reuse the name from @valid_attrs
venue(name: @valid_attrs.name) |> generate()

Venue
|> Ash.Changeset.for_create(:create, @valid_attrs)
|> Ash.create!(authorize?: false)
```

### Use `setup` for shared test prerequisites

**Always** use a `setup` block to create records that many tests depend on (e.g. tags, users), returning them in the context map. Destructure only what each test needs:

```elixir
# Good — create once in setup, destructure per test
setup do
  skill = tag(type: :skill) |> generate()
  location = tag(type: :location) |> generate()
  role = tag(type: :role) |> generate()
  %{tag_ids: [skill.id, location.id, role.id]}
end

test "given valid attrs, a venue is created", %{tag_ids: tag_ids} do
  # tag_ids available from setup
end

test "given missing fields, an error is raised" do
  # no destructuring needed — this test doesn't use tag_ids
end

# Bad — helper called repeatedly in every test
defp create_required_tags do
  skill = tag(type: :skill) |> generate()
  ...
end

test "given valid attrs, a venue is created" do
  tag_ids = create_required_tags()
  ...
end
```

### Describe blocks

One `describe` block per resource concern:

- **Actions**: use function name + arity range only (no full module path)
  `describe "authorize_user/1-2"`
- **Policies**: `describe "policies"`
- **Validations**: `describe "validations"`

### Use `load:` option instead of separate `Ash.load!`

**Always** pass `load:` directly to the action call instead of doing a separate `Ash.load!` afterwards.

```elixir
# Good — load inline
user = Accounts.create_user!(attrs, load: [:authorizations])

# Bad — separate load step
user = Accounts.create_user!(attrs)
user = Ash.load!(user, [:authorizations])
```

### Minimize `authorize?: false` in tests

**Only** use `authorize?: false` when the test has no suitable actor or is deliberately bypassing policies to test something else (e.g. verifying an empty table, loading relationships before the actor is known). When an actor is available and policies would pass naturally, let authorization run — this gives extra coverage for free.

```elixir
# Good — actor is provided, policies pass naturally
assert_raise Ash.Error.Invalid, ~r/at least one skill is required/, fn ->
  Venue
  |> Ash.Changeset.for_create(:create, %{name: "Test", tag_ids: bad_ids}, actor: user)
  |> Ash.create!()
end

# Good — no actor available, authorize?: false is necessary
assert [] = Ash.read!(Venue, authorize?: false)

# Bad — unnecessary bypass when actor is available
Venue
|> Ash.Changeset.for_create(:create, %{name: "Test", tag_ids: ids}, actor: user)
|> Ash.create!(authorize?: false)
```

### Never pass `authorize?: true` in tests

Passing `actor:` (even `actor: nil`) enables authorization automatically. Use `actor: nil` to test unauthenticated access instead of `authorize?: true`:

```elixir
# Good — actor implies authorization
Ash.read!(Venue, actor: user)

# Good — actor: nil tests unauthenticated access with authorization enabled
Ash.create!(changeset, actor: nil)

# Bad — redundant authorize?: true
Ash.read!(Venue, actor: user, authorize?: true)

# Bad — authorize?: true when actor: nil achieves the same thing
Ash.create!(changeset, authorize?: true)
```

### Log assertions

**Never** assert on log output (`capture_log`, `=~` on log strings) in tests. Logs are for observability, not behavior verification. Assert on return values, database state, or side effects instead.

### What to test (priority order)

1. **Policies** (if they exist) — test each role/actor combination. Use `can_*?` helpers or `Ash.can?`, assert/refute per role including `nil` (unauthenticated):

    ```elixir
    describe "policies" do
      test "given an admin, the resource can be read" do
        admin = generate(user(authorizations: [:scandic]))
        assert Accounts.can_read_users?(admin)
        refute Accounts.can_read_users?(nil)
      end
    end
    ```

2. **Actions with custom changes** — call domain functions directly and assert results/side effects:

    ```elixir
    describe "manage_authorizations/2-3" do
      test "given authorization types, the user has those authorizations" do
        user = generate(user())
        user = Accounts.manage_authorizations!(user, %{types: [:scandic, :hilton]})
        assert length(user.authorizations) == 2
      end
    end
    ```

3. **Validations** — use `assert_raise Ash.Error.Invalid` or `Ash.Test.assert_has_error`:

    ```elixir
    describe "validations" do
      test "given a duplicate user+type pair, an error is raised" do
        user = generate(user())
        generate(user_authorization(user_id: user.id, type: :scandic))

        assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
          generate(user_authorization(user_id: user.id, type: :scandic))
        end
      end
    end
    ```

4. **Calculations/aggregates** (if non-trivial) — use `Ash.calculate!` or load and assert.

### Assertion patterns

#### Prefer pattern matching with pin operators in assertions

**Always** use pattern matching with pin operators (`^`) in `assert` instead of binding a value and comparing with `==` afterwards. Extract known values upfront and pin them in the assertion:

```elixir
# Good — extract id upfront, pin in assertion
%{id: organization_id} = organization = organization() |> generate()

assert %Venue{organization_id: ^organization_id} =
         Venue
         |> Ash.Changeset.for_create(:create, attrs, actor: user)
         |> Ash.create!()

# Bad — bind and compare separately
organization = organization() |> generate()

assert %Venue{organization_id: organization_id} =
         Venue
         |> Ash.Changeset.for_create(:create, attrs, actor: user)
         |> Ash.create!()

assert organization_id == organization.id
```

#### Prefer map pattern match assertions over individual field assertions

**Always** use `assert %{...} = expression` to verify multiple fields at once instead of binding a variable and asserting each field separately with `==`. For fields that require non-pattern checks (e.g. `in`), bind the result and assert those separately:

```elixir
# Good — pattern match asserts multiple fields at once
assert %{
  title: "Head Bartender",
  description: "Weekend evening shift",
  source_url: "https://example.com/shift/42",
  hourly_rate: 25,
  start_date: ~N[2026-04-01 00:00:00],
  end_date: ~N[2026-09-01 00:00:00]
} = ShiftDataConverter.convert(shift_data)

# Good — bind only when non-pattern assertions (like `in`) are needed
result = ShiftDataConverter.convert(shift_data)

assert %{
  title: "Head Bartender",
  hourly_rate: 25
} = result

assert skill.id in result.tag_ids
assert location.id in result.tag_ids

# Bad — binding + individual == assertions
params = ShiftDataConverter.convert(shift_data)

assert params.title == "Head Bartender"
assert params.description == "Weekend evening shift"
assert params.hourly_rate == 25
```

#### Assert before and after

**Always** verify the state before performing the action under test, then assert the expected change afterwards. This ensures the test is actually proving the action caused the effect.

```elixir
# Good — verify precondition, then assert postcondition
test "given valid attrs, a user is created" do
  assert Enum.count(Accounts.list_users!()) == 0

  valid_attrs |> user() |> generate()

  assert Enum.count(Accounts.list_users!()) == 1
end

test "given a sign-in, a magic link email is sent" do
  assert_no_email_sent()

  Accounts.request_magic_link!(email)

  assert_email_sent(subject: ~r/sign in/)
end
```

#### Prefer `assert_lists_equal/2` for verifying list contents

**Always** use `assert_lists_equal/2` to verify exact list contents. It asserts both the elements and their count in a single call, regardless of order. Prefer it over counting, multiple `in`/`refute in` checks, or any combination of partial assertions:

```elixir
# Good — single assertion verifies exact contents
assert_lists_equal(result.matching_shift_ids, [shift1.id, shift2.id])
assert_lists_equal(user.authorizations, [:scandic, :hilton])

# Bad — only verifies count, not content
assert Enum.count(user.authorizations) == 2

# Bad — multiple assertions to verify the same list
assert shift1.id in result.matching_shift_ids
assert shift2.id in result.matching_shift_ids
refute shift3.id in result.matching_shift_ids
```

#### Prefer full string assertions over partial matches

**Always** assert the full string with `==` and a heredoc (`"""`) instead of using `=~` for partial substring checks. Full assertions catch regressions in formatting, ordering, and content that partial matches silently miss:

```elixir
# Good — assert the full string, any change is caught
assert email.text_body == """
       Here are the latest shifts available that match your profile:

       #{shift.title}
       #{skills}
       Read more: https://crewpoc.com/shifts/#{shift.id}

       --
       Change your profile settings here: https://crewpoc.com/profile/edit
       """

# Bad — partial matches miss formatting regressions and extra/missing content
assert email.text_body =~ shift.title
assert email.text_body =~ "/shifts/#{shift.id}"
assert email.text_body =~ "/profile/edit"
```

#### Always use bang (!) functions in tests

**Always** use the bang (`!`) version of functions in tests. For success cases, call the `!` function directly — no need to pattern match on `{:ok, _}`. For failure cases, use `assert_raise`.

```elixir
# Good — bang function, pattern match on the result directly
assert %{email: ^expected_email} = Accounts.create_user!(valid_attrs)

# Bad — unnecessary :ok match
assert {:ok, %{email: ^expected_email}} = Accounts.create_user(valid_attrs)
```

#### Testing failures

**Always** use the bang (`!`) version of the function with `assert_raise` when testing failures. Never match on `{:error, _}` tuples. **Always** include a `~r/message/` pattern to verify the specific error message — this catches regressions where the right exception type is raised for the wrong reason.

```elixir
# Good — bang function + assert_raise + message pattern
assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
  [user_id: user.id, type: :scandic] |> user_authorization() |> generate()
end

assert_raise Ash.Error.Forbidden, ~r/forbidden/, fn ->
  existing
  |> Ash.Changeset.for_update(:update, %{name: "Hacked"})
  |> Ash.update!(actor: other_user)
end

# Bad — no message pattern, any Invalid error passes
assert_raise Ash.Error.Invalid, fn ->
  [user_id: user.id, type: :scandic] |> user_authorization() |> generate()
end

# Bad — matching on error tuple
assert {:error, %Ash.Error.Invalid{}} =
         Accounts.authorize_user(user, %{type: :scandic})
```

## Tools

Use Tidewave MCP tools, as they let you interrogate the running application in various useful ways.

- Never attempt to start or stop a Phoenix application. Tidewave tools work by being connected to the running application, and starting or stopping it can cause issues.
- Use the `project_eval` tool to execute code in the running instance of the application. Eval `h Module.fun` to get documentation for a module or function.
- Always use `search_package_docs` to find relevant documentation before beginning work.

## Frontend (React)

The frontend is a **React 19 SPA**, not a LiveView app. The Phoenix backend serves a single bundled JS app via a static page; all UI and data fetching live client-side.

### Architecture

- **Entry point**: `assets/js/app/index.tsx` — mounts React (`createRoot`) into `<div id="app">` rendered by `CrewPocWeb.PageController` at `/`.
- **SPA layout**: `lib/crew_poc_web/components/layouts/spa_root.html.heex` is the root layout for the SPA page. It loads `priv/static/assets/app/index.js` as an ES module via `<script type="module" src={~p"/assets/app/index.js"}>`.
- **Other HEEx**: the only HEEx in the project is the two root layouts (`root.html.heex`, `spa_root.html.heex`) and the SPA mount template (`page_html/index.html.heex`, which is just `<div id="app"></div>`). Don't add new HEEx-rendered pages — new screens live in the React app.
- **Bundling**: esbuild bundles `js/app/index.tsx` with code-splitting (`--splitting --format=esm`) into `priv/static/assets/app/`. The bundle config lives in `config/config.exs` under `:esbuild`.
- **TypeScript**: `assets/tsconfig.json` uses `jsx: "react-jsx"`. Write new frontend code as `.ts` / `.tsx`. Note that `paths: { "*": ["../deps/*"] }` is configured so `import "phoenix"` etc. resolves to the Phoenix JS shipped via Hex.
- **LiveView is not used for application UI.** `phoenix_live_view` is only a dependency because `/dev/dashboard` (LiveDashboard) uses it. **Never** add `*_live.ex` modules, `live` routes in the browser scope, LiveView hooks, streams, colocated hooks, or `<.form>`/`to_form` server-rendered forms for the app.

### Data fetching (AshTypescript RPC)

- **Always** call backend Ash actions via the generated client in `assets/js/ash_rpc.ts` (which re-exports types from `assets/js/ash_types.ts`). Both files are auto-generated — **never** edit them manually. Regenerate with `mix ash_typescript.codegen` after changing exposed actions.
- The client posts to `/rpc/run` and `/rpc/validate`, routed in `CrewPocWeb.Router` to `CrewPocWeb.AshTypescriptRpcController`, which delegates to `AshTypescript.Rpc.run_action/3` and `validate_action/3`.
- CSRF is handled automatically: `getPhoenixCSRFToken()` reads the `meta[name='csrf-token']` tag from the root layout and `buildCSRFHeaders` injects `X-CSRF-Token`. Don't bypass this.
- To expose a new Ash action to the frontend, add an `rpc_action` entry in the domain's `typescript_rpc do` block, then regenerate the client.
- Codegen config (output paths, endpoints, field formatters — currently `camelCase` both directions) lives in `config/config.exs` under `:ash_typescript`.

### JS bundle rules

- Only the `app/index.tsx` → `assets/app/index.js` bundle and the `app.css` bundle are shipped.
  - **Never** reference an external vendored `<script src>` or `<link href>` in the layouts.
  - Import vendor deps via `package.json` and let esbuild bundle them.
  - **Never** write inline `<script>custom js</script>` tags inside HEEx templates — put logic in a React component or a plain TS module under `assets/js/`.

## Styling

- **Tailwind v4** with the new import syntax in `assets/css/app.css`. **Always** maintain this exact form:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/crew_poc_web";

- **Never** use `@apply` when writing raw CSS.
- **daisyUI** is enabled via `@plugin "../vendor/daisyui"` in `app.css`, with `light` (default) and `dark` themes defined inline. **Prefer daisyUI semantic classes** (`btn`, `card`, `bg-base-100`, `text-base-content`, `card-body`, etc.) over hand-rolled equivalents — this project standardizes on them. Use Tailwind utilities to fill gaps and customize spacing/layout.
- Custom Tailwind variants for LiveView loading states (`phx-click-loading`, `phx-submit-loading`, `phx-change-loading`) are defined in `app.css` but unused by the React app; leave them — they cost nothing and the file is otherwise managed.

## UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


<!-- usage-rules-start -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->

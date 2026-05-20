# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ash_typescript,
  output_file: "assets/js/ash_rpc.ts",
  run_endpoint: "/rpc/run",
  validate_endpoint: "/rpc/validate",
  input_field_formatter: :camel_case,
  output_field_formatter: :camel_case,
  require_tenant_parameters: false,
  generate_zod_schemas: false,
  generate_phx_channel_rpc_actions: false,
  generate_validation_functions: true,
  zod_import_path: "zod",
  zod_schema_suffix: "ZodSchema",
  phoenix_import_path: "phoenix",
  typed_controllers: [CrewPoc.CurrentUser],
  router: CrewPocWeb.Router,
  routes_output_file: "assets/js/routes.ts",
  typed_channels: [
    CrewPocWeb.ChatConversationChannel,
    CrewPocWeb.UserNotificationsChannel,
    CrewPocWeb.OrgFeedChannel
  ],
  typed_channels_output_file: "assets/js/ash_typed_channels.ts"

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true,
  known_types: [AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :admin,
        :postgres,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [:admin, :resources, :policies, :authorization, :domain, :execution]
    ]
  ]

config :crew_poc,
  ecto_repos: [CrewPoc.Repo],
  ash_domains: [
    CrewPoc.Accounts,
    CrewPoc.Venues,
    CrewPoc.Shifts,
    CrewPoc.Chat,
    CrewPoc.Feed,
    CrewPoc.Recognition
  ],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :crew_poc, CrewPocWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CrewPocWeb.ErrorHTML, json: CrewPocWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CrewPoc.PubSub

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :crew_poc, CrewPoc.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  crew_poc: [
    args:
      ~w(js/app/index.tsx --bundle --target=es2022 --outdir=../priv/static/assets/app --external:/fonts/* --external:/images/* --alias:@=. --splitting --format=esm),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" =>
        Enum.join(
          [
            Path.expand("../deps", __DIR__),
            Path.expand(Mix.Project.build_path()),
            Path.expand("../_build/dev", __DIR__)
          ],
          ":"
        )
    }
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  crew_poc: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

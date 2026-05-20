defmodule CrewPoc.Recognition.Shoutout do
  use Ash.Resource,
    domain: CrewPoc.Recognition,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias Ash.Changeset

  @org_topic_prefix CrewPocWeb.OrgFeedChannel.prefix()
  @shoutout_created_event CrewPocWeb.OrgFeedChannel.shoutout_created_event()

  postgres do
    table "shoutouts"
    repo CrewPoc.Repo

    references do
      reference :organization, on_delete: :delete
    end

    custom_indexes do
      index "body gin_trgm_ops", name: "shoutouts_body_gin_index", using: "GIN"
    end

    check_constraints do
      check_constraint :recipient_id, "no_self_shoutout",
        check: "sender_id <> recipient_id",
        message: "sender and recipient must differ"
    end
  end

  typescript do
    type_name "Shoutout"
  end

  resource do
    description "A peer-to-peer kudos: one sender, one recipient, plain text body."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:recipient_id, :body]

      change fn changeset, %{actor: actor} ->
        changeset
        |> Changeset.change_attribute(:sender_id, actor.id)
        |> Changeset.change_attribute(:organization_id, actor.organization_id)
      end

      validate fn changeset, _context ->
        sender_id = Changeset.get_attribute(changeset, :sender_id)
        recipient_id = Changeset.get_attribute(changeset, :recipient_id)

        if sender_id == recipient_id do
          {:error, field: :recipient_id, message: "sender and recipient must differ"}
        else
          :ok
        end
      end
    end

    read :search do
      argument :query, :ci_string do
        allow_nil? false
        constraints allow_empty?: true
        default ""
      end

      filter expr(contains(body, ^arg(:query)))

      prepare build(sort: [inserted_at: :desc])

      pagination offset?: true, default_limit: 12, required?: false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end
  end

  pub_sub do
    module CrewPocWeb.Endpoint

    publish @shoutout_created_event, :create, [@org_topic_prefix, :organization_id],
      public?: true,
      transform: :shoutout_summary
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid, allow_nil?: false, public?: true
    attribute :sender_id, :uuid, allow_nil?: false, public?: true
    attribute :recipient_id, :uuid, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :sender, CrewPoc.Accounts.User,
      attribute_writable?: true,
      define_attribute?: false,
      source_attribute: :sender_id

    belongs_to :recipient, CrewPoc.Accounts.User,
      attribute_writable?: true,
      define_attribute?: false,
      source_attribute: :recipient_id
  end

  calculations do
    calculate :shoutout_summary,
              :auto,
              expr(%{
                id: id,
                sender_id: sender_id,
                recipient_id: recipient_id,
                body: body,
                inserted_at: inserted_at
              }) do
      public? true
    end
  end
end

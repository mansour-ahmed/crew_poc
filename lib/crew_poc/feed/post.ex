defmodule CrewPoc.Feed.Post do
  use Ash.Resource,
    domain: CrewPoc.Feed,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias Ash.Changeset

  require Ash.Query

  @org_topic_prefix CrewPocWeb.OrgFeedChannel.prefix()
  @post_created_event CrewPocWeb.OrgFeedChannel.post_created_event()

  postgres do
    table "posts"
    repo CrewPoc.Repo

    references do
      reference :organization, on_delete: :delete
      reference :venue, on_delete: :delete
    end

    custom_indexes do
      index "title gin_trgm_ops", name: "posts_title_gin_index", using: "GIN"
      index "body gin_trgm_ops", name: "posts_body_gin_index", using: "GIN"
    end
  end

  typescript do
    type_name "Post"
    field_names acknowledged_by_actor?: "acknowledgedByActor"
  end

  resource do
    description "An announcement broadcast to the org or a specific venue."
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :title,
        :body,
        :original_locale,
        :requires_acknowledgement,
        :venue_id
      ]

      change fn changeset, %{actor: actor} ->
        changeset
        |> Changeset.change_attribute(:author_id, actor.id)
        |> Changeset.change_attribute(:organization_id, actor.organization_id)
      end
    end

    read :search do
      argument :query, :ci_string do
        allow_nil? false
        constraints allow_empty?: true
        default ""
      end

      filter expr(contains(title, ^arg(:query)) or contains(body, ^arg(:query)))

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

    publish @post_created_event, :create, [@org_topic_prefix, :organization_id],
      public?: true,
      transform: :feed_summary
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid, allow_nil?: false, public?: true
    attribute :venue_id, :uuid, allow_nil?: true, public?: true
    attribute :author_id, :uuid, allow_nil?: false, public?: true

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true
    attribute :original_locale, :string, allow_nil?: false, default: "en", public?: true

    attribute :requires_acknowledgement, :boolean,
      allow_nil?: false,
      default: false,
      public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :venue, CrewPoc.Venues.Venue,
      attribute_writable?: true,
      define_attribute?: false,
      allow_nil?: true

    belongs_to :author, CrewPoc.Accounts.User,
      attribute_writable?: true,
      define_attribute?: false,
      source_attribute: :author_id

    has_many :acknowledgements, CrewPoc.Feed.Acknowledgement
    has_many :translations, CrewPoc.Feed.PostTranslation
  end

  calculations do
    calculate :acknowledged_by_actor?,
              :boolean,
              expr(exists(acknowledgements, user_id == ^actor(:id))) do
      public? true
    end

    calculate :feed_summary,
              :auto,
              expr(%{
                id: id,
                organization_id: organization_id,
                venue_id: venue_id,
                author_id: author_id,
                title: title,
                inserted_at: inserted_at
              }) do
      public? true
    end
  end

  aggregates do
    count :ack_count, :acknowledgements do
      public? true
    end
  end
end

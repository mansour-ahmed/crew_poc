defmodule CrewPoc.Feed.Acknowledgement do
  use Ash.Resource,
    domain: CrewPoc.Feed,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias Ash.Changeset

  @org_topic_prefix CrewPocWeb.OrgFeedChannel.prefix()
  @acknowledgement_added_event CrewPocWeb.OrgFeedChannel.acknowledgement_added_event()

  postgres do
    table "acknowledgements"
    repo CrewPoc.Repo

    references do
      reference :organization, on_delete: :delete
      reference :post, on_delete: :delete
    end
  end

  typescript do
    type_name "Acknowledgement"
  end

  resource do
    description "Records that a user clicked the Acknowledge button on a Post."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:post_id]

      upsert? true
      upsert_identity :unique_post_user

      change fn changeset, %{actor: actor} ->
        changeset
        |> Changeset.change_attribute(:user_id, actor.id)
        |> Changeset.change_attribute(:organization_id, actor.organization_id)
      end
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

    publish @acknowledgement_added_event, :create, [@org_topic_prefix, :organization_id],
      public?: true,
      transform: :ack_summary
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid, allow_nil?: false, public?: true
    attribute :post_id, :uuid, allow_nil?: false, public?: true
    attribute :user_id, :uuid, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :post, CrewPoc.Feed.Post,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :user, CrewPoc.Accounts.User,
      attribute_writable?: true,
      define_attribute?: false
  end

  calculations do
    calculate :ack_summary,
              :auto,
              expr(%{
                id: id,
                post_id: post_id,
                user_id: user_id,
                organization_id: organization_id
              }) do
      public? true
    end
  end

  identities do
    identity :unique_post_user, [:post_id, :user_id]
  end
end

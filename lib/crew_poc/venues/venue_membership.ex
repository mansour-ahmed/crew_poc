defmodule CrewPoc.Venues.VenueMembership do
  use Ash.Resource,
    domain: CrewPoc.Venues,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  alias CrewPoc.Chat.Changes.AddConversationMember

  postgres do
    table "venue_memberships"
    repo CrewPoc.Repo
  end

  typescript do
    type_name "VenueMembership"
  end

  actions do
    defaults [:read]

    create :create do
      accept [:venue_id, :user_id, :organization_id]

      change {AddConversationMember, via: :venue_conversation}
    end

    destroy :destroy do
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid, allow_nil?: false, public?: true
    attribute :venue_id, :uuid, allow_nil?: false, public?: true
    attribute :user_id, :uuid, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :venue, CrewPoc.Venues.Venue,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :user, CrewPoc.Accounts.User,
      attribute_writable?: true,
      define_attribute?: false
  end

  identities do
    identity :unique_user_venue, [:user_id, :venue_id]
  end
end

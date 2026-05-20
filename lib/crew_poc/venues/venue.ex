defmodule CrewPoc.Venues.Venue do
  use Ash.Resource,
    domain: CrewPoc.Venues,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  alias Ash.Changeset
  alias CrewPoc.Chat
  alias CrewPoc.SlugHelpers

  postgres do
    table "venues"
    repo CrewPoc.Repo
  end

  typescript do
    type_name "Venue"
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :slug, :city, :timezone, :organization_id]

      change fn changeset, _context ->
        SlugHelpers.maybe_set_slug(changeset)
      end

      change fn changeset, _context ->
        Changeset.after_action(changeset, fn _changeset, venue ->
          Chat.create_venue_conversation!(venue.id, authorize?: false)
          {:ok, venue}
        end)
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

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :slug, :string, allow_nil?: false, public?: true
    attribute :city, :string, allow_nil?: false, public?: true
    # IANA time zone database identifier, e.g. "Europe/Helsinki"
    attribute :timezone, :string, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      allow_nil?: false,
      public?: true

    has_many :venue_memberships, CrewPoc.Venues.VenueMembership

    has_many :members, CrewPoc.Accounts.User do
      through [:venue_memberships, :user]
    end
  end

  identities do
    identity :unique_slug_per_org, [:organization_id, :slug]
  end
end

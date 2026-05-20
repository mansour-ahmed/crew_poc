defmodule CrewPoc.Accounts.Organization do
  use Ash.Resource,
    domain: CrewPoc.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  alias CrewPoc.SlugHelpers

  postgres do
    table "organizations"
    repo CrewPoc.Repo
  end

  typescript do
    type_name "Organization"
  end

  resource do
    description "A hospitality organization."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :slug]

      change fn changeset, _context ->
        SlugHelpers.maybe_set_slug(changeset)
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

    attribute :name, :string do
      allow_nil? false
    end

    attribute :slug, :string do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    has_many :users, CrewPoc.Accounts.User
  end

  aggregates do
    count :staff_count, :users
  end

  identities do
    identity :unique_name, [:name]
    identity :unique_slug, [:slug]
  end
end

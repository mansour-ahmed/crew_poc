defmodule CrewPoc.Shifts.Shift do
  use Ash.Resource,
    domain: CrewPoc.Shifts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "shifts"
    repo CrewPoc.Repo

    check_constraints do
      check_constraint :ends_at, "ends_after_starts",
        check: "ends_at > starts_at",
        message: "ends_at must be after starts_at"
    end
  end

  typescript do
    type_name "Shift"
  end

  resource do
    description "A scheduled work block at a venue."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :starts_at, :ends_at, :venue_id, :organization_id]

      validate compare(:ends_at, greater_than: :starts_at) do
        message "ends_at must be after starts_at"
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
    attribute :starts_at, :utc_datetime, allow_nil?: false, public?: true
    attribute :ends_at, :utc_datetime, allow_nil?: false, public?: true

    attribute :organization_id, :uuid, allow_nil?: false, public?: true
    attribute :venue_id, :uuid, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :venue, CrewPoc.Venues.Venue,
      attribute_writable?: true,
      define_attribute?: false

    has_many :shift_assignments, CrewPoc.Shifts.ShiftAssignment

    has_many :assignees, CrewPoc.Accounts.User do
      through [:shift_assignments, :user]
    end
  end

  calculations do
    calculate :status,
              :atom,
              expr(
                cond do
                  fragment("now()") < starts_at -> :upcoming
                  fragment("now()") < ends_at -> :active
                  true -> :finished
                end
              )
  end
end

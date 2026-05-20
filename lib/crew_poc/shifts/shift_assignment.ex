defmodule CrewPoc.Shifts.ShiftAssignment do
  use Ash.Resource,
    domain: CrewPoc.Shifts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  alias CrewPoc.Chat.Changes.AddConversationMember
  alias CrewPoc.Shifts.ShiftAssignment.Validations.UserBelongsToShiftVenue

  postgres do
    table "shift_assignments"
    repo CrewPoc.Repo

    references do
      reference :organization, on_delete: :delete
    end
  end

  typescript do
    type_name "ShiftAssignment"
  end

  resource do
    description "Assigns a user to a shift. Used to drive shift conversation membership."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:shift_id, :user_id, :organization_id]

      validate {UserBelongsToShiftVenue, []}

      change {AddConversationMember, via: :shift_conversation}
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
    attribute :shift_id, :uuid, allow_nil?: false, public?: true
    attribute :user_id, :uuid, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :shift, CrewPoc.Shifts.Shift,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :user, CrewPoc.Accounts.User,
      attribute_writable?: true,
      define_attribute?: false
  end

  identities do
    identity :unique_user_shift, [:user_id, :shift_id]
  end
end

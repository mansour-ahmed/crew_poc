defmodule CrewPoc.Chat.Conversation do
  use Ash.Resource,
    domain: CrewPoc.Chat,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  alias Ash.Changeset
  alias CrewPoc.Shifts.Shift
  alias CrewPoc.Venues.Venue

  postgres do
    table "conversations"
    repo CrewPoc.Repo

    references do
      reference :organization, on_delete: :delete
      reference :venue, on_delete: :delete
      reference :shift, on_delete: :delete
    end

    custom_indexes do
      index [:venue_id],
        unique: true,
        where: "kind = 'venue_channel'",
        name: "conversations_unique_venue_channel_index"

      index [:shift_id],
        unique: true,
        where: "kind = 'shift_channel'",
        name: "conversations_unique_shift_channel_index"
    end

    check_constraints do
      check_constraint :venue_id, "venue_or_shift_present",
        check: "venue_id IS NOT NULL OR shift_id IS NOT NULL",
        message: "at least one of venue_id or shift_id must be present"
    end
  end

  typescript do
    type_name "Conversation"
  end

  resource do
    description "A chat conversation, either a venue conversation or a shift conversation."
  end

  actions do
    defaults [:read]

    # Conversations the actor cares about right now: venue channels they belong
    # to + shift channels for shifts that are currently in progress.
    read :list_pinned do
      filter expr(
               kind == :venue_channel or
                 (kind == :shift_channel and shift.starts_at <= now() and
                    shift.ends_at > now())
             )
    end

    create :create_venue_conversation do
      accept [:venue_id]

      change fn changeset, _context ->
        venue_id = Changeset.get_attribute(changeset, :venue_id)
        venue = Ash.get!(Venue, venue_id, authorize?: false)

        changeset
        |> Changeset.change_attribute(:kind, :venue_channel)
        |> Changeset.change_attribute(:title, venue.name)
        |> Changeset.change_attribute(:organization_id, venue.organization_id)
      end
    end

    create :create_shift_conversation do
      accept [:shift_id]

      change fn changeset, _context ->
        shift_id = Changeset.get_attribute(changeset, :shift_id)
        shift = Ash.get!(Shift, shift_id, authorize?: false)

        changeset
        |> Changeset.change_attribute(:kind, :shift_channel)
        |> Changeset.change_attribute(:title, shift.name)
        |> Changeset.change_attribute(:venue_id, shift.venue_id)
        |> Changeset.change_attribute(:organization_id, shift.organization_id)
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(exists(conversation_memberships, user_id == ^actor(:id)))
    end

    policy action_type(:create) do
      authorize_if always()
    end
  end

  validations do
    validate present([:venue_id, :shift_id], at_least: 1)
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid, allow_nil?: false, public?: true

    attribute :kind, :atom do
      constraints one_of: [:venue_channel, :shift_channel]
      allow_nil? false
      public? true
    end

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :venue_id, :uuid, allow_nil?: true, public?: true
    attribute :shift_id, :uuid, allow_nil?: true, public?: true

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

    belongs_to :shift, CrewPoc.Shifts.Shift,
      attribute_writable?: true,
      define_attribute?: false,
      allow_nil?: true

    has_many :conversation_memberships, CrewPoc.Chat.ConversationMembership

    has_many :messages, CrewPoc.Chat.Message

    has_many :members, CrewPoc.Accounts.User do
      through [:conversation_memberships, :user]
    end
  end
end

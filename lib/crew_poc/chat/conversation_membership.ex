defmodule CrewPoc.Chat.ConversationMembership do
  use Ash.Resource,
    domain: CrewPoc.Chat,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  @user_topic_prefix CrewPocWeb.UserNotificationsChannel.prefix()
  @unread_changed_event CrewPocWeb.UserNotificationsChannel.unread_changed_event()

  postgres do
    table "conversation_memberships"
    repo CrewPoc.Repo

    references do
      reference :conversation, on_delete: :delete
    end
  end

  typescript do
    type_name "ConversationMembership"
  end

  resource do
    description "Links a user to a conversation, tracks last-read timestamp."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:conversation_id, :user_id]
    end

    destroy :destroy do
      require_atomic? false
    end

    update :mark_read do
      accept []
      require_atomic? false
      change set_attribute(:last_read_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if always()
    end

    policy action(:mark_read) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  pub_sub do
    module CrewPocWeb.Endpoint

    publish @unread_changed_event, :mark_read, [@user_topic_prefix, :user_id],
      public?: true,
      transform: :unread_summary
  end

  attributes do
    uuid_primary_key :id

    attribute :conversation_id, :uuid, allow_nil?: false, public?: true
    attribute :user_id, :uuid, allow_nil?: false, public?: true
    attribute :last_read_at, :utc_datetime, allow_nil?: true, public?: true

    timestamps()
  end

  relationships do
    belongs_to :conversation, CrewPoc.Chat.Conversation,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :user, CrewPoc.Accounts.User,
      attribute_writable?: true,
      define_attribute?: false
  end

  calculations do
    calculate :unread_summary,
              :auto,
              expr(%{
                conversation_id: conversation_id,
                user_id: user_id,
                last_read_at: last_read_at
              }) do
      public? true
    end
  end

  identities do
    identity :unique_user_conversation, [:conversation_id, :user_id]
  end
end

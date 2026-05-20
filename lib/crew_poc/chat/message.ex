defmodule CrewPoc.Chat.Message do
  use Ash.Resource,
    domain: CrewPoc.Chat,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  @conversation_topic_prefix CrewPocWeb.ChatConversationChannel.prefix()
  @message_created_event CrewPocWeb.ChatConversationChannel.message_created_event()

  postgres do
    table "messages"
    repo CrewPoc.Repo

    references do
      reference :conversation, on_delete: :delete
    end
  end

  typescript do
    type_name "Message"
  end

  resource do
    description "A chat message in a conversation."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:conversation_id, :body]

      change fn changeset, %{actor: actor} ->
        Ash.Changeset.change_attribute(changeset, :author_id, actor.id)
      end

      change fn changeset, %{actor: actor} ->
        Ash.Changeset.change_attribute(changeset, :organization_id, actor.organization_id)
      end

      validate string_length(:body, min: 1)

      change CrewPoc.Chat.Changes.BroadcastUnreadToMembers
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(exists(conversation.conversation_memberships, user_id == ^actor(:id)))
    end

    policy action_type(:create) do
      authorize_if expr(exists(conversation.conversation_memberships, user_id == ^actor(:id)))
    end
  end

  pub_sub do
    module CrewPocWeb.Endpoint

    publish @message_created_event, :create, [@conversation_topic_prefix, :conversation_id],
      public?: true,
      transform: :message_summary
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid, allow_nil?: false, public?: true
    attribute :conversation_id, :uuid, allow_nil?: false, public?: true
    attribute :author_id, :uuid, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :conversation, CrewPoc.Chat.Conversation,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :author, CrewPoc.Accounts.User,
      attribute_writable?: true,
      define_attribute?: false,
      source_attribute: :author_id
  end

  calculations do
    calculate :message_summary,
              :auto,
              expr(%{
                id: id,
                conversation_id: conversation_id,
                author_id: author_id,
                body: body,
                inserted_at: inserted_at
              }) do
      public? true
    end
  end
end

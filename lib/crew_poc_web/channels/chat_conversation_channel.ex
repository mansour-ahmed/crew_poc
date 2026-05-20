defmodule CrewPocWeb.ChatConversationChannel do
  use AshTypescript.TypedChannel
  use Phoenix.Channel

  alias CrewPoc.Chat
  alias CrewPoc.Chat.Conversation

  @prefix "chat:conversation"
  @message_created_event :message_created

  typed_channel do
    topic "chat:conversation:*"

    resource CrewPoc.Chat.Message do
      publish @message_created_event
    end
  end

  @spec prefix() :: binary()
  def prefix, do: @prefix

  @spec topic(binary()) :: binary()
  def topic(conversation_id), do: "#{@prefix}:#{conversation_id}"

  @spec message_created_event() :: atom()
  def message_created_event, do: @message_created_event

  @impl true
  def join(@prefix <> ":" <> conversation_id, _payload, socket) do
    actor = %{id: socket.assigns.current_user_id}

    case Chat.get_conversation(conversation_id, actor: actor) do
      {:ok, %Conversation{}} -> {:ok, socket}
      {:error, _} -> {:error, %{reason: "unauthorized"}}
    end
  end
end

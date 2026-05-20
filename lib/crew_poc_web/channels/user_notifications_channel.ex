defmodule CrewPocWeb.UserNotificationsChannel do
  use AshTypescript.TypedChannel
  use Phoenix.Channel

  @prefix "user"
  @unread_changed_event :unread_changed

  typed_channel do
    topic "user:*"

    resource CrewPoc.Chat.ConversationMembership do
      publish @unread_changed_event
    end
  end

  @spec prefix() :: binary()
  def prefix, do: @prefix

  @spec topic(binary()) :: binary()
  def topic(user_id), do: "#{@prefix}:#{user_id}"

  @spec unread_changed_event() :: atom()
  def unread_changed_event, do: @unread_changed_event

  @impl true
  def join(@prefix <> ":" <> user_id, _payload, socket) do
    if socket.assigns.current_user_id == user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
end

defmodule CrewPoc.Chat.Changes.BroadcastUnreadToMembers do
  @moduledoc """
  After a Message is created, broadcasts the `unread_changed` event on every
  non-author member's `user:<user_id>` topic, so their unread badges update
  live.
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias CrewPoc.Chat.ConversationMembership
  alias CrewPocWeb.Endpoint
  alias CrewPocWeb.UserNotificationsChannel

  require Ash.Query

  @event Atom.to_string(UserNotificationsChannel.unread_changed_event())

  @impl true
  def change(changeset, _opts, _context) do
    Changeset.after_action(changeset, fn _changeset, message ->
      broadcast(message)
      {:ok, message}
    end)
  end

  defp broadcast(message) do
    ConversationMembership
    |> Ash.Query.filter(
      conversation_id == ^message.conversation_id and user_id != ^message.author_id
    )
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn %ConversationMembership{user_id: user_id} ->
      topic = UserNotificationsChannel.topic(user_id)

      Endpoint.broadcast(topic, @event, %{
        conversation_id: message.conversation_id
      })
    end)
  end
end

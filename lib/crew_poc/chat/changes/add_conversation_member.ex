defmodule CrewPoc.Chat.Changes.AddConversationMember do
  @moduledoc """
  After-action change that adds the actor's user as a `ConversationMembership`
  on the Conversation associated with the parent join record
  (VenueMembership / ShiftAssignment) being created.

  Deletion of the parent Venue/Shift is handled by a DB-level FK cascade,
  so no destroy-time mirroring is needed.

  Options:

    * `:via` — `:venue_conversation` or `:shift_conversation`. Selects how to
      locate the target Conversation from the join record (by `venue_id` or by
      `shift_id`).
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias CrewPoc.Chat
  alias CrewPoc.Chat.Conversation
  alias CrewPoc.Chat.ConversationMembership

  require Ash.Query

  @impl true
  def init(opts) do
    if opts[:via] in [:venue_conversation, :shift_conversation] do
      {:ok, opts}
    else
      {:error,
       "expected :via to be :venue_conversation or :shift_conversation, got: #{inspect(opts[:via])}"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    Changeset.after_action(changeset, fn _changeset, record ->
      add_member(record, opts[:via])
      {:ok, record}
    end)
  end

  defp add_member(record, via) do
    with %Conversation{} = conversation <- find_conversation(record, via),
         nil <- find_conversation_membership(conversation.id, record.user_id) do
      Chat.create_conversation_membership!(
        %{conversation_id: conversation.id, user_id: record.user_id},
        authorize?: false
      )
    else
      _ -> :ok
    end
  end

  defp find_conversation(record, :venue_conversation) do
    Conversation
    |> Ash.Query.filter(venue_id == ^record.venue_id and kind == :venue_channel)
    |> Ash.read_one!(authorize?: false)
  end

  defp find_conversation(record, :shift_conversation) do
    Conversation
    |> Ash.Query.filter(shift_id == ^record.shift_id and kind == :shift_channel)
    |> Ash.read_one!(authorize?: false)
  end

  defp find_conversation_membership(conversation_id, user_id) do
    ConversationMembership
    |> Ash.Query.filter(conversation_id == ^conversation_id and user_id == ^user_id)
    |> Ash.read_one!(authorize?: false)
  end
end

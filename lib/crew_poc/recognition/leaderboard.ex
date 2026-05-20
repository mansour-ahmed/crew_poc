defmodule CrewPoc.Recognition.Leaderboard do
  @moduledoc """
  Cross-resource analytics for `CrewPoc.Recognition`. Aggregates `Shoutout` rows
  into ranked `{user, count}` entries.
  """

  alias CrewPoc.Accounts.User
  alias CrewPoc.Recognition.Shoutout

  require Ash.Query

  @doc """
  Returns the top `limit` shoutout recipients in the last 7 days for the
  actor's organization. Each entry is `{user, count}` sorted by count desc.
  """
  @spec top_recipients_this_week(Ash.Resource.record() | nil, keyword()) ::
          [{User.t(), non_neg_integer()}]
  def top_recipients_this_week(actor, opts \\ [])

  def top_recipients_this_week(nil, _opts), do: []

  def top_recipients_this_week(%{organization_id: organization_id}, opts) do
    limit = Keyword.get(opts, :limit, 5)

    organization_id
    |> count_recipients(limit)
    |> load_recipients()
  end

  defp count_recipients(organization_id, limit) do
    since = DateTime.add(DateTime.utc_now(), -7, :day)

    Shoutout
    |> Ash.Query.filter(organization_id == ^organization_id and inserted_at >= ^since)
    |> Ash.read!(authorize?: false)
    |> Enum.frequencies_by(& &1.recipient_id)
    |> Enum.sort_by(fn {_recipient_id, count} -> count end, :desc)
    |> Enum.take(limit)
  end

  defp load_recipients([]), do: []

  defp load_recipients([_ | _] = entries) do
    recipient_ids = Enum.map(entries, fn {recipient_id, _count} -> recipient_id end)

    users_by_id =
      User
      |> Ash.Query.filter(id in ^recipient_ids)
      |> Ash.read!(authorize?: false)
      |> Map.new(&{&1.id, &1})

    Enum.map(entries, fn {recipient_id, count} ->
      {Map.fetch!(users_by_id, recipient_id), count}
    end)
  end
end

defmodule CrewPoc.Feed.Items do
  @moduledoc """
  Cross-domain activity feed. Merges recent `Feed.Post`s, `Recognition.Shoutout`s,
  and (for the given actor) today's `Accounts.User` celebrations into one
  timestamp-sorted stream tagged with `kind` for the frontend to switch on.
  """

  alias CrewPoc.Accounts.User
  alias CrewPoc.Feed.Post
  alias CrewPoc.Recognition.Shoutout

  require Ash.Query

  @type item :: %{
          kind: :post | :shoutout | :celebration,
          item: struct(),
          timestamp: DateTime.t()
        }

  @spec list_items(Ash.Resource.record() | nil, keyword()) :: [item()]
  def list_items(actor, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)

    posts = load_kind(Post, :post, actor, limit)
    shoutouts = load_kind(Shoutout, :shoutout, actor, limit)
    celebrations = load_celebrations(actor)

    (posts ++ shoutouts ++ celebrations)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(limit)
  end

  defp load_kind(resource, kind, actor, limit) do
    resource
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!(actor: actor)
    |> Enum.map(&%{kind: kind, item: &1, timestamp: &1.inserted_at})
  end

  defp load_celebrations(nil), do: []

  defp load_celebrations(actor) do
    today_start = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")

    User
    |> Ash.Query.for_read(:celebrating_today, %{}, actor: actor)
    |> Ash.read!()
    |> Enum.map(&%{kind: :celebration, item: &1, timestamp: today_start})
  end
end

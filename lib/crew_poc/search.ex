defmodule CrewPoc.Search do
  @moduledoc """
  Cross-domain search aggregator. Calls the per-resource `:search` actions on
  `Feed.Post` and `Recognition.Shoutout`, then merges the hits into one list
  tagged with the resource `kind` for the frontend to switch on.
  """

  alias CrewPoc.Feed
  alias CrewPoc.Recognition

  @type hit :: %{kind: :post | :shoutout, item: struct(), timestamp: DateTime.t()}

  @spec global(Ash.Resource.record() | nil, binary() | Ash.CiString.t(), keyword()) :: [hit()]
  def global(actor, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 12)

    posts = Feed.search_posts!(query, actor: actor, page: [limit: limit, offset: 0])

    shoutouts =
      Recognition.search_shoutouts!(query, actor: actor, page: [limit: limit, offset: 0])

    post_hits =
      posts
      |> page_results()
      |> Enum.map(&%{kind: :post, item: &1, timestamp: &1.inserted_at})

    shoutout_hits =
      shoutouts
      |> page_results()
      |> Enum.map(&%{kind: :shoutout, item: &1, timestamp: &1.inserted_at})

    (post_hits ++ shoutout_hits)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(limit)
  end

  defp page_results(%Ash.Page.Offset{results: results}), do: results
  defp page_results(results) when is_list(results), do: results
end

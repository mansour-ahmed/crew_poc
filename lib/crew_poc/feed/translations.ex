defmodule CrewPoc.Feed.Translations do
  @moduledoc """
  Translation cache for `CrewPoc.Feed.Post`. `ensure_translation/2` returns the
  cached `PostTranslation` row for `(post_id, target_locale)` if one exists;
  otherwise it runs the prompt-backed `:translate` action against the post's
  title and body, persists the row, and returns it.
  """

  alias CrewPoc.Feed.Post
  alias CrewPoc.Feed.PostTranslation
  alias CrewPoc.Feed.TranslatedPost

  require Ash.Query

  @spec ensure_translation(binary(), binary()) ::
          {:ok, PostTranslation.t()} | {:error, term()}
  def ensure_translation(post_id, target_locale)
      when is_binary(post_id) and is_binary(target_locale) do
    cached =
      PostTranslation
      |> Ash.Query.filter(post_id == ^post_id and target_locale == ^target_locale)
      |> Ash.read_one(authorize?: false)

    case cached do
      {:ok, %PostTranslation{} = translation} ->
        {:ok, translation}

      {:ok, nil} ->
        with {:ok, post} <- Ash.get(Post, post_id, authorize?: false),
             {:ok, translated} <- run_translate(post, target_locale) do
          insert_translation(post, target_locale, translated)
        end

      {:error, _} = error ->
        error
    end
  end

  defp run_translate(%Post{} = post, target_locale) do
    PostTranslation
    |> Ash.ActionInput.for_action(:translate, %{
      title: post.title,
      body: post.body,
      source_locale: post.original_locale,
      target_locale: target_locale
    })
    |> Ash.run_action(authorize?: false)
  end

  defp insert_translation(%Post{} = post, target_locale, %TranslatedPost{title: title, body: body}) do
    PostTranslation
    |> Ash.Changeset.for_create(:create, %{
      organization_id: post.organization_id,
      post_id: post.id,
      target_locale: target_locale,
      title: title,
      body: body
    })
    |> Ash.create(authorize?: false)
  end
end

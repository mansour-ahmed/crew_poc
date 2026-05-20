defmodule CrewPoc.Feed.PostTranslation do
  use Ash.Resource,
    domain: CrewPoc.Feed,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAi, AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  alias Ash.ActionInput
  alias CrewPoc.Feed.Post
  alias CrewPoc.Feed.TranslatedPost

  require Ash.Query

  postgres do
    table "post_translations"
    repo CrewPoc.Repo

    references do
      reference :organization, on_delete: :delete
      reference :post, on_delete: :delete
    end
  end

  typescript do
    type_name "PostTranslation"
  end

  resource do
    description "Cached LLM translation of a Post's title and body."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:organization_id, :post_id, :target_locale, :title, :body]
    end

    # Looks up an existing translation row for (post_id, target_locale); on a miss,
    # runs the prompt-backed `:translate` action and persists the result.
    action :ensure_for, :struct do
      constraints instance_of: __MODULE__

      argument :post_id, :uuid, allow_nil?: false
      argument :target_locale, :string, allow_nil?: false

      run fn input, _context ->
        __MODULE__.ensure_for(
          input.arguments.post_id,
          input.arguments.target_locale
        )
      end
    end

    action :translate, TranslatedPost do
      argument :title, :string, allow_nil?: false
      argument :body, :string, allow_nil?: false
      argument :source_locale, :string, allow_nil?: false
      argument :target_locale, :string, allow_nil?: false

      run prompt("openrouter:google/gemini-3.5-flash",
            prompt: """
            Translate the following announcement from <%= @input.arguments.source_locale %> to <%= @input.arguments.target_locale %>.
            Return the translated title and body. Do not add commentary, quotes, or labels.

            Title: <%= @input.arguments.title %>
            Body: <%= @input.arguments.body %>
            """,
            tools: false
          )
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action(:translate) do
      authorize_if always()
    end

    policy action(:ensure_for) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid, allow_nil?: false, public?: true
    attribute :post_id, :uuid, allow_nil?: false, public?: true
    attribute :target_locale, :string, allow_nil?: false, public?: true
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :post, CrewPoc.Feed.Post,
      attribute_writable?: true,
      define_attribute?: false
  end

  identities do
    identity :unique_post_target_locale, [:post_id, :target_locale]
  end

  @doc """
  Returns the cached translation row for `(post_id, target_locale)` if one
  exists; otherwise runs the prompt-backed `:translate` action against the
  post's title and body, persists the row, and returns it.
  """
  @spec ensure_for(binary(), binary()) :: {:ok, struct()} | {:error, term()}
  def ensure_for(post_id, target_locale)
      when is_binary(post_id) and is_binary(target_locale) do
    case fetch_cached(post_id, target_locale) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        with {:ok, post} <- Ash.get(Post, post_id, authorize?: false),
             {:ok, translated} <- run_translate(post, target_locale) do
          insert_translation(post, target_locale, translated)
        end

      {:error, _} = error ->
        error
    end
  end

  defp fetch_cached(post_id, target_locale) do
    case __MODULE__
         |> Ash.Query.filter(post_id == ^post_id and target_locale == ^target_locale)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> :miss
      {:ok, row} -> {:ok, row}
      {:error, _} = err -> err
    end
  end

  defp run_translate(%Post{} = post, target_locale) do
    __MODULE__
    |> ActionInput.for_action(:translate, %{
      title: post.title,
      body: post.body,
      source_locale: post.original_locale,
      target_locale: target_locale
    })
    |> Ash.run_action(authorize?: false)
  end

  defp insert_translation(%Post{} = post, target_locale, %TranslatedPost{
         title: title,
         body: body
       }) do
    __MODULE__
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

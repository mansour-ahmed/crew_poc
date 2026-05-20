defmodule CrewPoc.Feed.TranslationsTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Feed
  alias CrewPoc.Feed.PostTranslation
  alias CrewPoc.Feed.Translations

  require Ash.Query

  setup do
    organization = organization() |> generate()

    author =
      [organization_id: organization.id]
      |> user()
      |> generate()

    post =
      Feed.create_post!(
        %{
          title: "Tervetuloa",
          body: "Tervetuloa tiimiin",
          original_locale: "fi",
          requires_acknowledgement: false
        },
        actor: author
      )

    %{organization: organization, post: post}
  end

  describe "ensure_translation/2 cache hit" do
    test "given a cached translation, the prompt action is not invoked", %{
      organization: organization,
      post: post
    } do
      %{id: cached_id} =
        Ash.Seed.seed!(PostTranslation, %{
          organization_id: organization.id,
          post_id: post.id,
          target_locale: "es",
          title: "Bienvenidos",
          body: "Bienvenidos al equipo"
        })

      assert {:ok,
              %PostTranslation{
                id: ^cached_id,
                title: "Bienvenidos",
                body: "Bienvenidos al equipo"
              }} = Translations.ensure_translation(post.id, "es")
    end

    test "given two cache hits, no duplicate row is created", %{
      organization: organization,
      post: post
    } do
      Ash.Seed.seed!(PostTranslation, %{
        organization_id: organization.id,
        post_id: post.id,
        target_locale: "pt",
        title: "Bem-vindos",
        body: "Bem-vindos à equipe"
      })

      {:ok, _} = Translations.ensure_translation(post.id, "pt")
      {:ok, _} = Translations.ensure_translation(post.id, "pt")

      rows =
        PostTranslation
        |> Ash.Query.filter(post_id == ^post.id and target_locale == "pt")
        |> Ash.read!(authorize?: false)

      assert Enum.count(rows) == 1
    end
  end
end

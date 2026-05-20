defmodule CrewPoc.SearchTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Feed
  alias CrewPoc.Recognition
  alias CrewPoc.Search

  describe "global/2" do
    test "given a query matching both a post and a shoutout, both kinds are returned" do
      organization = organization() |> generate()

      author =
        [organization_id: organization.id]
        |> user()
        |> generate()

      recipient =
        [organization_id: organization.id]
        |> user()
        |> generate()

      post =
        Feed.create_post!(
          %{
            title: "Lounge cleanup roster",
            body: "Lounge cleanup is on Thursday",
            original_locale: "en",
            requires_acknowledgement: false
          },
          actor: author
        )

      shoutout =
        Recognition.create_shoutout!(
          %{recipient_id: recipient.id, body: "Lounge looked spotless"},
          actor: author
        )

      hits = Search.global(author, "lounge")

      ids =
        hits
        |> Enum.map(& &1.item.id)
        |> Enum.sort()

      assert_lists_equal(ids, Enum.sort([post.id, shoutout.id]))

      kinds =
        hits
        |> Enum.map(& &1.kind)
        |> Enum.sort()

      assert kinds == [:post, :shoutout]
    end

    test "given a query that matches nothing, an empty list is returned" do
      organization = organization() |> generate()

      author =
        [organization_id: organization.id]
        |> user()
        |> generate()

      Feed.create_post!(
        %{
          title: "Title",
          body: "Body",
          original_locale: "en",
          requires_acknowledgement: false
        },
        actor: author
      )

      assert [] = Search.global(author, "xyzzy-no-match")
    end
  end
end

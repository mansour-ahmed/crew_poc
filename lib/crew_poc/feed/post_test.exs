defmodule CrewPoc.Feed.PostTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Feed
  alias CrewPoc.Feed.Post

  require Ash.Query

  @valid_attrs %{
    title: "All-hands tomorrow",
    body: "Reminder: all-hands at 10:00 in the staff lounge.",
    original_locale: "en",
    requires_acknowledgement: false
  }

  setup do
    organization = organization() |> generate()

    author =
      [organization_id: organization.id]
      |> user()
      |> generate()

    venue =
      [organization_id: organization.id]
      |> venue()
      |> generate()

    %{organization_id: organization.id, author: author, venue_id: venue.id}
  end

  describe "create_post/1" do
    test "given valid org-wide attrs, a post is created", %{author: author} do
      %{id: author_id, organization_id: organization_id} = author

      assert %Post{
               title: "All-hands tomorrow",
               body: "Reminder: all-hands at 10:00 in the staff lounge.",
               original_locale: "en",
               requires_acknowledgement: false,
               author_id: ^author_id,
               organization_id: ^organization_id,
               venue_id: nil
             } = Feed.create_post!(@valid_attrs, actor: author)
    end

    test "given a venue_id, the post is scoped to that venue", %{
      author: author,
      venue_id: venue_id
    } do
      attrs = Map.put(@valid_attrs, :venue_id, venue_id)

      assert %Post{venue_id: ^venue_id} = Feed.create_post!(attrs, actor: author)
    end
  end

  describe "search/1" do
    test "given a query matching a title, the post is returned", %{author: author} do
      %{id: match_id} = Feed.create_post!(@valid_attrs, actor: author)

      Feed.create_post!(
        %{@valid_attrs | title: "Unrelated topic", body: "Nothing to see"},
        actor: author
      )

      assert [%Post{id: ^match_id}] = Feed.search_posts!("all-hands", actor: author)
    end

    test "given a query matching the body, the post is returned", %{author: author} do
      %{id: match_id} =
        Feed.create_post!(
          %{@valid_attrs | title: "Topic", body: "Please remember to wash your hands."},
          actor: author
        )

      assert [%Post{id: ^match_id}] = Feed.search_posts!("wash", actor: author)
    end

    test "given a query that matches nothing, no posts are returned", %{author: author} do
      Feed.create_post!(@valid_attrs, actor: author)

      assert [] = Feed.search_posts!("xyzzy-not-present", actor: author)
    end
  end

  describe "aggregates and calculations" do
    test "given two acknowledgements, ack_count is 2", %{author: author, organization_id: org_id} do
      post = Feed.create_post!(@valid_attrs, actor: author)

      reader1 =
        [organization_id: org_id]
        |> user()
        |> generate()

      reader2 =
        [organization_id: org_id]
        |> user()
        |> generate()

      [post_id: post.id, user_id: reader1.id]
      |> acknowledgement()
      |> generate()

      [post_id: post.id, user_id: reader2.id]
      |> acknowledgement()
      |> generate()

      assert %Post{ack_count: 2} = Ash.load!(post, :ack_count, authorize?: false)
    end

    test "given the actor has acked, acknowledged_by_actor? is true", %{
      author: author,
      organization_id: org_id
    } do
      post = Feed.create_post!(@valid_attrs, actor: author)

      reader =
        [organization_id: org_id]
        |> user()
        |> generate()

      [post_id: post.id, user_id: reader.id]
      |> acknowledgement()
      |> generate()

      assert %Post{acknowledged_by_actor?: true} =
               Ash.load!(post, :acknowledged_by_actor?, actor: reader)
    end

    test "given the actor has not acked, acknowledged_by_actor? is false", %{
      author: author,
      organization_id: org_id
    } do
      post = Feed.create_post!(@valid_attrs, actor: author)

      reader =
        [organization_id: org_id]
        |> user()
        |> generate()

      assert %Post{acknowledged_by_actor?: false} =
               Ash.load!(post, :acknowledged_by_actor?, actor: reader)
    end
  end
end

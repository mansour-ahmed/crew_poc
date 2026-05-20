defmodule CrewPoc.Feed.AcknowledgementTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Feed
  alias CrewPoc.Feed.Acknowledgement

  require Ash.Query

  setup do
    organization = organization() |> generate()

    author =
      [organization_id: organization.id]
      |> user()
      |> generate()

    reader =
      [organization_id: organization.id]
      |> user()
      |> generate()

    post =
      [organization_id: organization.id, author_id: author.id]
      |> post()
      |> generate()

    %{organization_id: organization.id, post: post, reader: reader}
  end

  describe "create_acknowledgement/2" do
    test "given a post and reader, an acknowledgement is created", %{
      post: post,
      reader: reader,
      organization_id: organization_id
    } do
      assert [] = Ash.read!(Acknowledgement, authorize?: false)

      %{id: post_id} = post
      %{id: reader_id} = reader

      assert %Acknowledgement{
               post_id: ^post_id,
               user_id: ^reader_id,
               organization_id: ^organization_id
             } = Feed.create_acknowledgement!(post.id, actor: reader)

      assert [%Acknowledgement{}] = Ash.read!(Acknowledgement, authorize?: false)
    end

    test "given the same reader acks twice, the second call returns the same row", %{
      post: post,
      reader: reader
    } do
      first = Feed.create_acknowledgement!(post.id, actor: reader)
      second = Feed.create_acknowledgement!(post.id, actor: reader)

      assert first.id == second.id

      rows =
        Acknowledgement
        |> Ash.Query.filter(post_id == ^post.id and user_id == ^reader.id)
        |> Ash.read!(authorize?: false)

      assert Enum.count(rows) == 1
    end
  end

  describe "identities" do
    test "given two distinct users acking the same post, both rows persist", %{
      post: post,
      organization_id: organization_id
    } do
      reader1 =
        [organization_id: organization_id]
        |> user()
        |> generate()

      reader2 =
        [organization_id: organization_id]
        |> user()
        |> generate()

      Feed.create_acknowledgement!(post.id, actor: reader1)
      Feed.create_acknowledgement!(post.id, actor: reader2)

      rows =
        Acknowledgement
        |> Ash.Query.filter(post_id == ^post.id)
        |> Ash.read!(authorize?: false)

      assert_lists_equal(Enum.map(rows, & &1.user_id), [reader1.id, reader2.id])
    end
  end
end

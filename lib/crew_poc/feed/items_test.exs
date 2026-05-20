defmodule CrewPoc.Feed.ItemsTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Feed
  alias CrewPoc.Feed.Items
  alias CrewPoc.Recognition

  describe "list_items/2" do
    test "given posts, shoutouts and celebrating users, the merged stream tags each kind" do
      organization = organization() |> generate()

      author =
        [organization_id: organization.id]
        |> user()
        |> generate()

      sender =
        [organization_id: organization.id]
        |> user()
        |> generate()

      recipient =
        [organization_id: organization.id]
        |> user()
        |> generate()

      [organization_id: organization.id, birthday: today_date()]
      |> user()
      |> generate()

      Feed.create_post!(
        %{
          title: "Welcome",
          body: "Welcome to the team",
          original_locale: "en",
          requires_acknowledgement: false
        },
        actor: author
      )

      Recognition.create_shoutout!(
        %{recipient_id: recipient.id, body: "Great service"},
        actor: sender
      )

      items = Items.list_items(author)

      kinds =
        items
        |> Enum.map(& &1.kind)
        |> Enum.uniq()
        |> Enum.sort()

      assert kinds == [:celebration, :post, :shoutout]
    end

    test "given no actor, celebrations are omitted but posts and shoutouts still merge" do
      organization = organization() |> generate()

      author =
        [organization_id: organization.id]
        |> user()
        |> generate()

      recipient =
        [organization_id: organization.id]
        |> user()
        |> generate()

      Feed.create_post!(
        %{
          title: "Notice",
          body: "Please clock in on time",
          original_locale: "en",
          requires_acknowledgement: false
        },
        actor: author
      )

      Recognition.create_shoutout!(
        %{recipient_id: recipient.id, body: "Nice job"},
        actor: author
      )

      items = Items.list_items(nil)

      kinds =
        items
        |> Enum.map(& &1.kind)
        |> Enum.uniq()
        |> Enum.sort()

      assert kinds == [:post, :shoutout]
    end

    test "given mixed timestamps, items are sorted by descending timestamp" do
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
            title: "First",
            body: "Older",
            original_locale: "en",
            requires_acknowledgement: false
          },
          actor: author
        )

      Process.sleep(1_100)

      shoutout =
        Recognition.create_shoutout!(
          %{recipient_id: recipient.id, body: "Newer"},
          actor: author
        )

      [first, second | _] = Items.list_items(author)

      assert first.kind == :shoutout
      assert first.item.id == shoutout.id
      assert second.kind == :post
      assert second.item.id == post.id
    end
  end

  defp today_date do
    today = Date.utc_today()
    Date.new!(1990, today.month, today.day)
  end
end

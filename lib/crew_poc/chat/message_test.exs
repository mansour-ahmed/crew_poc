defmodule CrewPoc.Chat.MessageTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Chat
  alias CrewPoc.Chat.Message

  require Ash.Query

  setup do
    organization = organization() |> generate()

    venue =
      [organization_id: organization.id]
      |> venue()
      |> generate()

    conversation = venue_conversation(venue_id: venue.id)

    member =
      [organization_id: organization.id]
      |> user()
      |> generate()

    [
      organization_id: organization.id,
      conversation_id: conversation.id,
      user_id: member.id
    ]
    |> conversation_membership()
    |> generate()

    %{organization: organization, conversation: conversation, member: member}
  end

  describe "send_message/1" do
    test "given a member actor and non-empty body, a message is created", %{
      organization: %{id: organization_id},
      conversation: %{id: conversation_id},
      member: %{id: author_id} = author
    } do
      assert %Message{
               organization_id: ^organization_id,
               conversation_id: ^conversation_id,
               author_id: ^author_id,
               body: "Hello team!"
             } =
               Chat.send_message!(
                 %{conversation_id: conversation_id, body: "Hello team!"},
                 actor: author
               )
    end

    test "given a non-member actor, the create is forbidden", %{
      organization: organization,
      conversation: %{id: conversation_id}
    } do
      non_member =
        [organization_id: organization.id]
        |> user()
        |> generate()

      assert_raise Ash.Error.Forbidden, ~r/forbidden/, fn ->
        Chat.send_message!(
          %{conversation_id: conversation_id, body: "Hi"},
          actor: non_member
        )
      end
    end

    test "given an empty body, an error is raised", %{
      conversation: %{id: conversation_id},
      member: member
    } do
      assert_raise Ash.Error.Invalid, ~r/body is required/, fn ->
        Chat.send_message!(%{conversation_id: conversation_id, body: ""}, actor: member)
      end
    end
  end

  describe "policies" do
    test "given a member actor, only conversations they're in surface messages", %{
      organization: organization,
      conversation: conversation,
      member: member
    } do
      Chat.send_message!(
        %{conversation_id: conversation.id, body: "visible"},
        actor: member
      )

      other_venue =
        [organization_id: organization.id]
        |> venue()
        |> generate()

      other_conversation = venue_conversation(venue_id: other_venue.id)

      other_member =
        [organization_id: organization.id]
        |> user()
        |> generate()

      [
        organization_id: organization.id,
        conversation_id: other_conversation.id,
        user_id: other_member.id
      ]
      |> conversation_membership()
      |> generate()

      Chat.send_message!(
        %{conversation_id: other_conversation.id, body: "hidden"},
        actor: other_member
      )

      visible = Chat.list_messages!(actor: member)

      assert_lists_equal(Enum.map(visible, & &1.body), ["visible"])
    end
  end
end

defmodule CrewPoc.Chat.ConversationTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Chat
  alias CrewPoc.Chat.Conversation

  require Ash.Query

  setup do
    organization = organization() |> generate()

    venue =
      [organization_id: organization.id]
      |> venue()
      |> generate()

    %{organization: organization, venue: venue}
  end

  describe "venue conversation auto-creation" do
    test "given a Venue is created, a venue Conversation exists with venue's name as title",
         %{
           organization: %{id: organization_id},
           venue: %{id: venue_id, name: venue_name}
         } do
      assert %Conversation{
               kind: :venue_channel,
               title: ^venue_name,
               organization_id: ^organization_id,
               venue_id: ^venue_id,
               shift_id: nil
             } = venue_conversation(venue_id: venue_id)
    end

    test "given a venue already has a conversation, a manual duplicate is rejected", %{
      venue: %{id: venue_id}
    } do
      assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
        Chat.create_venue_conversation!(venue_id)
      end
    end
  end

  describe "shift conversation auto-creation" do
    setup %{organization: organization, venue: venue} do
      shift =
        [organization_id: organization.id, venue_id: venue.id, name: "Friday evening"]
        |> shift()
        |> generate()

      %{shift: shift}
    end

    test "given a Shift is created, a shift Conversation exists with shift's name as title",
         %{
           organization: %{id: organization_id},
           venue: %{id: venue_id},
           shift: %{id: shift_id}
         } do
      assert %Conversation{
               kind: :shift_channel,
               title: "Friday evening",
               organization_id: ^organization_id,
               venue_id: ^venue_id,
               shift_id: ^shift_id
             } = shift_conversation(shift_id: shift_id)
    end

    test "given a shift already has a conversation, a manual duplicate is rejected", %{
      shift: %{id: shift_id}
    } do
      assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
        Chat.create_shift_conversation!(shift_id)
      end
    end
  end

  describe "policies" do
    test "given an actor who is a member, the conversation is returned", %{
      organization: organization,
      venue: venue
    } do
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

      assert {:ok, returned} = Chat.get_conversation(conversation.id, actor: member)
      assert returned.id == conversation.id
    end

    test "given an actor who is not a member, the conversation is hidden", %{
      organization: organization,
      venue: venue
    } do
      conversation = venue_conversation(venue_id: venue.id)

      non_member =
        [organization_id: organization.id]
        |> user()
        |> generate()

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} =
               Chat.get_conversation(conversation.id, actor: non_member)
    end
  end
end

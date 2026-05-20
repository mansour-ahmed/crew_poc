defmodule CrewPoc.Chat.Changes.AddConversationMemberTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Chat.Conversation
  alias CrewPoc.Chat.ConversationMembership
  alias CrewPoc.Chat.Message
  alias CrewPoc.Shifts
  alias CrewPoc.Venues

  require Ash.Query

  setup do
    organization = organization() |> generate()

    venue =
      [organization_id: organization.id]
      |> venue()
      |> generate()

    user =
      [organization_id: organization.id]
      |> user()
      |> generate()

    %{organization: organization, venue: venue, user: user}
  end

  describe "via venue conversation" do
    test "given VenueMembership is created, a ConversationMembership is added to the venue conversation",
         %{organization: organization, venue: venue, user: user} do
      conversation = venue_conversation(venue_id: venue.id)

      refute_conversation_membership(conversation.id, user.id)

      Venues.create_venue_membership!(%{
        organization_id: organization.id,
        venue_id: venue.id,
        user_id: user.id
      })

      assert_conversation_membership(conversation.id, user.id)
    end
  end

  describe "via shift conversation" do
    setup %{organization: organization, venue: venue, user: user} do
      [organization_id: organization.id, venue_id: venue.id, user_id: user.id]
      |> venue_membership()
      |> generate()

      shift =
        [organization_id: organization.id, venue_id: venue.id]
        |> shift()
        |> generate()

      %{shift: shift}
    end

    test "given ShiftAssignment is created, a ConversationMembership is added to the shift conversation",
         %{organization: organization, shift: shift, user: user} do
      conversation = shift_conversation(shift_id: shift.id)

      refute_conversation_membership(conversation.id, user.id)

      Shifts.create_shift_assignment!(%{
        organization_id: organization.id,
        shift_id: shift.id,
        user_id: user.id
      })

      assert_conversation_membership(conversation.id, user.id)
    end
  end

  describe "auto-created conversations" do
    test "given a Venue is created, a venue Conversation exists for it", %{
      organization: organization
    } do
      %{id: new_venue_id} =
        [organization_id: organization.id]
        |> venue()
        |> generate()

      assert %Conversation{kind: :venue_channel, venue_id: ^new_venue_id} =
               Conversation
               |> Ash.Query.filter(venue_id == ^new_venue_id and kind == :venue_channel)
               |> Ash.read_one!(authorize?: false)
    end

    test "given a Shift is created, a shift Conversation exists for it", %{
      organization: organization,
      venue: venue
    } do
      %{id: new_shift_id} =
        [organization_id: organization.id, venue_id: venue.id]
        |> shift()
        |> generate()

      assert %Conversation{kind: :shift_channel, shift_id: ^new_shift_id} =
               Conversation
               |> Ash.Query.filter(shift_id == ^new_shift_id and kind == :shift_channel)
               |> Ash.read_one!(authorize?: false)
    end
  end

  describe "cascade on parent deletion" do
    test "given a Venue is deleted at the DB level, its Conversation, memberships, and messages cascade",
         %{organization: organization, venue: venue, user: user} do
      [organization_id: organization.id, venue_id: venue.id, user_id: user.id]
      |> venue_membership()
      |> generate()

      conversation = venue_conversation(venue_id: venue.id)

      [
        organization_id: organization.id,
        conversation_id: conversation.id,
        author_id: user.id
      ]
      |> message()
      |> generate()

      assert_conversation_membership(conversation.id, user.id)
      assert_message_in_conversation(conversation.id)

      {:ok, _} = CrewPoc.Repo.query("DELETE FROM venues WHERE id = '#{venue.id}'")

      refute_conversation(conversation.id)
      refute_conversation_membership(conversation.id, user.id)
      refute_message_in_conversation(conversation.id)
    end

    test "given a Shift is deleted at the DB level, its Conversation, memberships, and messages cascade",
         %{organization: organization, venue: venue, user: user} do
      [organization_id: organization.id, venue_id: venue.id, user_id: user.id]
      |> venue_membership()
      |> generate()

      shift =
        [organization_id: organization.id, venue_id: venue.id]
        |> shift()
        |> generate()

      shift_conversation = shift_conversation(shift_id: shift.id)

      Shifts.create_shift_assignment!(%{
        organization_id: organization.id,
        shift_id: shift.id,
        user_id: user.id
      })

      [
        organization_id: organization.id,
        conversation_id: shift_conversation.id,
        author_id: user.id
      ]
      |> message()
      |> generate()

      assert_conversation_membership(shift_conversation.id, user.id)
      assert_message_in_conversation(shift_conversation.id)

      {:ok, _} = CrewPoc.Repo.query("DELETE FROM shifts WHERE id = '#{shift.id}'")

      refute_conversation(shift_conversation.id)
      refute_conversation_membership(shift_conversation.id, user.id)
      refute_message_in_conversation(shift_conversation.id)
    end
  end

  defp assert_conversation_membership(conversation_id, user_id) do
    assert ConversationMembership
           |> Ash.Query.filter(conversation_id == ^conversation_id and user_id == ^user_id)
           |> Ash.exists?(authorize?: false)
  end

  defp refute_conversation_membership(conversation_id, user_id) do
    refute ConversationMembership
           |> Ash.Query.filter(conversation_id == ^conversation_id and user_id == ^user_id)
           |> Ash.exists?(authorize?: false)
  end

  defp refute_conversation(conversation_id) do
    refute Conversation
           |> Ash.Query.filter(id == ^conversation_id)
           |> Ash.exists?(authorize?: false)
  end

  defp assert_message_in_conversation(conversation_id) do
    assert Message
           |> Ash.Query.filter(conversation_id == ^conversation_id)
           |> Ash.exists?(authorize?: false)
  end

  defp refute_message_in_conversation(conversation_id) do
    refute Message
           |> Ash.Query.filter(conversation_id == ^conversation_id)
           |> Ash.exists?(authorize?: false)
  end
end

defmodule CrewPoc.Chat.ConversationMembershipTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Chat
  alias CrewPoc.Chat.ConversationMembership

  require Ash.Query

  setup do
    organization = organization() |> generate()

    venue =
      [organization_id: organization.id]
      |> venue()
      |> generate()

    conversation = venue_conversation(venue_id: venue.id)

    user =
      [organization_id: organization.id]
      |> user()
      |> generate()

    %{organization: organization, venue: venue, conversation: conversation, user: user}
  end

  describe "create_conversation_membership/1" do
    test "given valid attrs, a membership is created", %{
      conversation: %{id: conversation_id},
      user: %{id: user_id}
    } do
      assert %ConversationMembership{
               conversation_id: ^conversation_id,
               user_id: ^user_id,
               last_read_at: nil
             } =
               Chat.create_conversation_membership!(%{
                 conversation_id: conversation_id,
                 user_id: user_id
               })
    end

    test "given a duplicate conversation+user pair, an error is raised", %{
      conversation: conversation,
      user: user
    } do
      attrs = %{
        conversation_id: conversation.id,
        user_id: user.id
      }

      Chat.create_conversation_membership!(attrs)

      assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
        Chat.create_conversation_membership!(attrs)
      end
    end
  end

  describe "mark_conversation_read/2" do
    setup %{conversation: conversation, user: user} do
      membership =
        [conversation_id: conversation.id, user_id: user.id]
        |> conversation_membership()
        |> generate()

      %{membership: membership}
    end

    test "given the actor owns the membership, last_read_at is updated", %{
      membership: membership,
      user: user
    } do
      assert membership.last_read_at == nil

      before = DateTime.utc_now(:second)

      updated = Chat.mark_conversation_read!(membership, actor: user)

      assert updated.last_read_at != nil
      assert DateTime.compare(updated.last_read_at, before) in [:gt, :eq]
    end

    test "given a different actor, the update is forbidden", %{
      organization: organization,
      membership: membership
    } do
      other_user =
        [organization_id: organization.id]
        |> user()
        |> generate()

      assert_raise Ash.Error.Forbidden, ~r/forbidden/, fn ->
        Chat.mark_conversation_read!(membership, actor: other_user)
      end
    end
  end

  describe "policies" do
    test "given an actor, only their own memberships are returned", %{
      organization: organization,
      conversation: conversation,
      user: user
    } do
      [conversation_id: conversation.id, user_id: user.id]
      |> conversation_membership()
      |> generate()

      other_user =
        [organization_id: organization.id]
        |> user()
        |> generate()

      [conversation_id: conversation.id, user_id: other_user.id]
      |> conversation_membership()
      |> generate()

      memberships = Chat.list_conversation_memberships!(actor: user)

      assert_lists_equal(Enum.map(memberships, & &1.user_id), [user.id])
    end
  end
end

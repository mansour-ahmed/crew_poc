defmodule CrewPocWeb.ChatConversationChannelTest do
  use CrewPocWeb.ChannelCase, async: true

  alias CrewPocWeb.ChatConversationChannel
  alias CrewPocWeb.UserSocket

  setup do
    organization = generate(organization())

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

  describe "join/3" do
    test "given a member of the conversation, the join succeeds", %{
      organization: organization,
      venue: venue,
      user: user
    } do
      [organization_id: organization.id, venue_id: venue.id, user_id: user.id]
      |> venue_membership()
      |> generate()

      conversation = venue_conversation(venue_id: venue.id)

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      assert {:ok, _payload, %Phoenix.Socket{}} =
               subscribe_and_join(
                 socket,
                 ChatConversationChannel,
                 ChatConversationChannel.topic(conversation.id)
               )
    end

    test "given a non-member, the join is rejected", %{
      organization: organization,
      venue: venue
    } do
      non_member =
        [organization_id: organization.id]
        |> user()
        |> generate()

      conversation = venue_conversation(venue_id: venue.id)

      {:ok, socket} = connect(UserSocket, %{"user_id" => non_member.id})

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(
                 socket,
                 ChatConversationChannel,
                 ChatConversationChannel.topic(conversation.id)
               )
    end

    test "given a non-existent conversation id, the join is rejected", %{user: user} do
      missing_id = Ash.UUID.generate()

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(
                 socket,
                 ChatConversationChannel,
                 ChatConversationChannel.topic(missing_id)
               )
    end
  end
end

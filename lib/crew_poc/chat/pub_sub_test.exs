defmodule CrewPoc.Chat.PubSubTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Chat
  alias CrewPocWeb.ChatConversationChannel
  alias CrewPocWeb.UserNotificationsChannel

  require Ash.Query

  setup do
    organization = organization() |> generate()

    venue =
      [organization_id: organization.id]
      |> venue()
      |> generate()

    conversation = venue_conversation(venue_id: venue.id)

    author =
      [organization_id: organization.id]
      |> user()
      |> generate()

    [conversation_id: conversation.id, user_id: author.id]
    |> conversation_membership()
    |> generate()

    %{organization: organization, conversation: conversation, author: author}
  end

  describe "message_created broadcast" do
    test "given a message is sent, a message_created event is broadcast on the conversation topic",
         %{conversation: conversation, author: author} do
      Phoenix.PubSub.subscribe(CrewPoc.PubSub, ChatConversationChannel.topic(conversation.id))

      Chat.send_message!(
        %{conversation_id: conversation.id, body: "hello"},
        actor: author
      )

      assert_receive %Phoenix.Socket.Broadcast{
        event: "message_created",
        topic: topic
      }

      assert topic == ChatConversationChannel.topic(conversation.id)
    end
  end

  describe "unread_changed broadcast" do
    test "given a non-author member exists, an unread_changed event is broadcast on their user topic when a message is sent",
         %{organization: organization, conversation: conversation, author: author} do
      other_member =
        [organization_id: organization.id]
        |> user()
        |> generate()

      [conversation_id: conversation.id, user_id: other_member.id]
      |> conversation_membership()
      |> generate()

      Phoenix.PubSub.subscribe(CrewPoc.PubSub, UserNotificationsChannel.topic(other_member.id))

      Chat.send_message!(
        %{conversation_id: conversation.id, body: "hello"},
        actor: author
      )

      assert_receive %Phoenix.Socket.Broadcast{
        event: "unread_changed",
        topic: topic,
        payload: %{conversation_id: conversation_id}
      }

      assert topic == UserNotificationsChannel.topic(other_member.id)
      assert conversation_id == conversation.id
    end

    test "given the message author is the only member, no unread_changed event is broadcast", %{
      conversation: conversation,
      author: author
    } do
      Phoenix.PubSub.subscribe(CrewPoc.PubSub, UserNotificationsChannel.topic(author.id))

      Chat.send_message!(
        %{conversation_id: conversation.id, body: "hello"},
        actor: author
      )

      refute_receive %Phoenix.Socket.Broadcast{event: "unread_changed"}, 100
    end

    test "given mark_read is called, an unread_changed event is broadcast on the user topic", %{
      conversation: conversation,
      author: author
    } do
      membership =
        CrewPoc.Chat.ConversationMembership
        |> Ash.Query.filter(conversation_id == ^conversation.id and user_id == ^author.id)
        |> Ash.read_one!(authorize?: false)

      Phoenix.PubSub.subscribe(CrewPoc.PubSub, UserNotificationsChannel.topic(author.id))

      Chat.mark_conversation_read!(membership, actor: author)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "unread_changed",
        topic: topic
      }

      assert topic == UserNotificationsChannel.topic(author.id)
    end
  end
end

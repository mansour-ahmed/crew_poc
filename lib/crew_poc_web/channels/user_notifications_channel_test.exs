defmodule CrewPocWeb.UserNotificationsChannelTest do
  use CrewPocWeb.ChannelCase, async: true

  alias CrewPocWeb.UserNotificationsChannel
  alias CrewPocWeb.UserSocket

  setup do
    organization = generate(organization())

    user =
      [organization_id: organization.id]
      |> user()
      |> generate()

    %{organization: organization, user: user}
  end

  describe "join/3" do
    test "given the user joins their own topic, the join succeeds", %{user: user} do
      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      assert {:ok, _payload, %Phoenix.Socket{}} =
               subscribe_and_join(
                 socket,
                 UserNotificationsChannel,
                 UserNotificationsChannel.topic(user.id)
               )
    end

    test "given the user joins another user's topic, the join is rejected", %{
      organization: organization,
      user: user
    } do
      other_user =
        [organization_id: organization.id]
        |> user()
        |> generate()

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(
                 socket,
                 UserNotificationsChannel,
                 UserNotificationsChannel.topic(other_user.id)
               )
    end
  end
end

defmodule CrewPoc.Recognition.LeaderboardTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Recognition
  alias CrewPoc.Recognition.Leaderboard
  alias CrewPoc.Recognition.Shoutout

  setup do
    organization = organization() |> generate()

    sender =
      [organization_id: organization.id]
      |> user()
      |> generate()

    recipient =
      [organization_id: organization.id]
      |> user()
      |> generate()

    %{organization_id: organization.id, sender: sender, recipient: recipient}
  end

  describe "top_recipients_this_week/1" do
    test "given multiple shoutouts, the top recipient is ranked first", %{
      sender: sender,
      recipient: recipient,
      organization_id: organization_id
    } do
      runner_up =
        [organization_id: organization_id]
        |> user()
        |> generate()

      %{id: top_id} = recipient
      %{id: runner_up_id} = runner_up

      Recognition.create_shoutout!(
        %{recipient_id: top_id, body: "One"},
        actor: sender
      )

      Recognition.create_shoutout!(
        %{recipient_id: top_id, body: "Two"},
        actor: sender
      )

      Recognition.create_shoutout!(
        %{recipient_id: runner_up_id, body: "Three"},
        actor: sender
      )

      assert [{%{id: ^top_id}, 2}, {%{id: ^runner_up_id}, 1}] =
               Leaderboard.top_recipients_this_week(sender)
    end

    test "given a shoutout older than 7 days, it is excluded", %{
      sender: sender,
      recipient: recipient,
      organization_id: organization_id
    } do
      %{id: recipient_id} = recipient

      Ash.Seed.seed!(Shoutout, %{
        organization_id: organization_id,
        sender_id: sender.id,
        recipient_id: recipient.id,
        body: "Older shoutout",
        inserted_at: DateTime.add(DateTime.utc_now(), -10, :day)
      })

      assert [] = Leaderboard.top_recipients_this_week(sender)

      Recognition.create_shoutout!(
        %{recipient_id: recipient.id, body: "Recent shoutout"},
        actor: sender
      )

      assert [{%{id: ^recipient_id}, 1}] = Leaderboard.top_recipients_this_week(sender)
    end

    test "given no shoutouts, an empty list is returned", %{sender: sender} do
      assert [] = Leaderboard.top_recipients_this_week(sender)
    end
  end
end

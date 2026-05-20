defmodule CrewPoc.Recognition.ShoutoutTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Recognition
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

  describe "create_shoutout/2" do
    test "given valid attrs, a shoutout is created", %{
      sender: sender,
      recipient: recipient,
      organization_id: organization_id
    } do
      %{id: sender_id} = sender
      %{id: recipient_id} = recipient

      assert %Shoutout{
               sender_id: ^sender_id,
               recipient_id: ^recipient_id,
               organization_id: ^organization_id,
               body: "Excellent service tonight"
             } =
               Recognition.create_shoutout!(
                 %{recipient_id: recipient_id, body: "Excellent service tonight"},
                 actor: sender
               )
    end

  end

  describe "validations" do
    test "given sender == recipient, an error is raised", %{sender: sender} do
      assert_raise Ash.Error.Invalid, ~r/sender and recipient must differ/, fn ->
        Recognition.create_shoutout!(
          %{recipient_id: sender.id, body: "Self-praise"},
          actor: sender
        )
      end
    end
  end

  describe "check constraints" do
    test "given sender == recipient inserted via Ash.Seed, the DB rejects it", %{
      sender: sender,
      organization_id: organization_id
    } do
      assert_raise Ash.Error.Invalid, ~r/sender and recipient must differ/, fn ->
        Ash.Seed.seed!(Shoutout, %{
          organization_id: organization_id,
          sender_id: sender.id,
          recipient_id: sender.id,
          body: "Self-praise"
        })
      end
    end
  end

  describe "search_shoutouts/1" do
    test "given a query matching the body, the shoutout is returned", %{
      sender: sender,
      recipient: recipient
    } do
      %{id: match_id} =
        Recognition.create_shoutout!(
          %{recipient_id: recipient.id, body: "Spectacular plating"},
          actor: sender
        )

      Recognition.create_shoutout!(
        %{recipient_id: recipient.id, body: "Great cleanup"},
        actor: sender
      )

      assert [%Shoutout{id: ^match_id}] =
               Recognition.search_shoutouts!("spectacular", actor: sender)
    end
  end
end

defmodule CrewPocWeb.OrgFeedChannel do
  use AshTypescript.TypedChannel
  use Phoenix.Channel

  alias CrewPoc.Accounts

  @prefix "org"
  @post_created_event :post_created
  @shoutout_created_event :shoutout_created
  @acknowledgement_added_event :acknowledgement_added

  typed_channel do
    topic "org:*"

    resource CrewPoc.Feed.Post do
      publish @post_created_event
    end

    resource CrewPoc.Feed.Acknowledgement do
      publish @acknowledgement_added_event
    end

    resource CrewPoc.Recognition.Shoutout do
      publish @shoutout_created_event
    end
  end

  @spec prefix() :: binary()
  def prefix, do: @prefix

  @spec topic(binary()) :: binary()
  def topic(organization_id), do: "#{@prefix}:#{organization_id}"

  @spec post_created_event() :: atom()
  def post_created_event, do: @post_created_event

  @spec shoutout_created_event() :: atom()
  def shoutout_created_event, do: @shoutout_created_event

  @spec acknowledgement_added_event() :: atom()
  def acknowledgement_added_event, do: @acknowledgement_added_event

  @impl true
  def join(@prefix <> ":" <> organization_id, _payload, socket) do
    actor = %{id: socket.assigns.current_user_id}

    case Accounts.get_user(actor.id, actor: actor) do
      {:ok, %{organization_id: ^organization_id}} -> {:ok, socket}
      _ -> {:error, %{reason: "unauthorized"}}
    end
  end
end

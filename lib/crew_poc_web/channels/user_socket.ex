defmodule CrewPocWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:conversation:*", CrewPocWeb.ChatConversationChannel
  channel "user:*", CrewPocWeb.UserNotificationsChannel
  channel "org:*", CrewPocWeb.OrgFeedChannel

  @impl true
  def connect(%{"user_id" => user_id}, socket, _connect_info)
      when is_binary(user_id) and byte_size(user_id) > 0 do
    {:ok, assign(socket, :current_user_id, user_id)}
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "users_socket:#{socket.assigns.current_user_id}"
end

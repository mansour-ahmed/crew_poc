defmodule CrewPocWeb.Plugs.CurrentUser do
  import Plug.Conn

  alias CrewPoc.Accounts.User
  alias CrewPoc.CurrentUser

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    current_user =
      conn
      |> CurrentUser.get_current_user_id()
      |> load_user()

    conn
    |> assign(:current_user, current_user)
    |> Ash.PlugHelpers.set_actor(current_user)
  end

  @spec load_user(nil) :: nil
  defp load_user(nil), do: nil

  @spec load_user(String.t()) :: User.t() | nil
  defp load_user(user_id) do
    case Ash.get(User, user_id, authorize?: false) do
      {:ok, %User{} = user} -> user
      _ -> nil
    end
  end
end

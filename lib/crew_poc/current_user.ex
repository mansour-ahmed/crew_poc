defmodule CrewPoc.CurrentUser do
  use AshTypescript.TypedController

  alias CrewPoc.Accounts.User

  @session_key :current_user_id

  typed_controller do
    module_name CrewPocWeb.CurrentUserController

    post :switch_user do
      argument :user_id, :string, allow_nil?: false

      run fn conn, %{user_id: user_id} ->
        case Ash.get(User, user_id, authorize?: false) do
          {:ok, %User{id: ^user_id}} ->
            conn
            |> Plug.Conn.put_session(@session_key, user_id)
            |> Plug.Conn.send_resp(204, "")

          {:error, _} ->
            Plug.Conn.send_resp(conn, 404, "user not found")
        end
      end
    end
  end

  @spec get_current_user_id(Plug.Conn.t()) :: String.t() | nil
  def get_current_user_id(conn), do: Plug.Conn.get_session(conn, @session_key)
end

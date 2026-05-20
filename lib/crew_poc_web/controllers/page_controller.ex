defmodule CrewPocWeb.PageController do
  use CrewPocWeb, :controller

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, :index)
  end
end

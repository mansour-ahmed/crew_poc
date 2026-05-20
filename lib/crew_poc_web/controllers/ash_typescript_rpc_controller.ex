defmodule CrewPocWeb.AshTypescriptRpcController do
  use CrewPocWeb, :controller

  @spec run(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def run(conn, params) do
    result = AshTypescript.Rpc.run_action(:crew_poc, conn, params)
    json(conn, result)
  end

  @spec validate(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def validate(conn, params) do
    result = AshTypescript.Rpc.validate_action(:crew_poc, conn, params)
    json(conn, result)
  end
end

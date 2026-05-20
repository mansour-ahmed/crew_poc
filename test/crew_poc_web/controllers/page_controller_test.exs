defmodule CrewPocWeb.PageControllerTest do
  use CrewPocWeb.ConnCase, async: true

  test "given a GET request to '/', the SPA mount div is rendered", %{conn: conn} do
    assert html_response(get(conn, ~p"/"), 200) =~ ~s|<div id="app">|
  end
end

defmodule CrewPoc.CurrentUserTest do
  use CrewPocWeb.ConnCase, async: true

  alias CrewPoc.CurrentUser

  describe "POST /api/switch_user" do
    test "given a valid user_id, the session is set and 204 is returned", %{conn: conn} do
      user = user() |> generate()

      conn = post(conn, ~p"/api/switch_user", %{user_id: user.id})

      assert response(conn, 204)
      assert get_session(conn, :current_user_id) == user.id
    end

    test "given a non-existent user_id, 404 is returned", %{conn: conn} do
      missing_id = Ash.UUID.generate()

      conn = post(conn, ~p"/api/switch_user", %{user_id: missing_id})

      assert response(conn, 404) =~ "user not found"
      assert get_session(conn, :current_user_id) == nil
    end

    test "given no user_id, 422 is returned", %{conn: conn} do
      conn = post(conn, ~p"/api/switch_user", %{})

      assert %{"errors" => [%{"field" => "user_id"} | _]} = json_response(conn, 422)
      assert get_session(conn, :current_user_id) == nil
    end

    test "given a different actor switches, the session is replaced", %{conn: conn} do
      first = user() |> generate()
      second = user() |> generate()

      first_conn = post(conn, ~p"/api/switch_user", %{user_id: first.id})
      assert get_session(first_conn, :current_user_id) == first.id

      second_conn = post(first_conn, ~p"/api/switch_user", %{user_id: second.id})
      assert get_session(second_conn, :current_user_id) == second.id
    end
  end

  describe "get_current_user_id/1" do
    test "given a conn with no session value set, nil is returned", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{})

      assert CurrentUser.get_current_user_id(conn) == nil
    end

    test "given a conn with the session value set, the value is returned", %{conn: conn} do
      user_id = Ash.UUID.generate()
      conn = Plug.Test.init_test_session(conn, %{current_user_id: user_id})

      assert CurrentUser.get_current_user_id(conn) == user_id
    end
  end
end

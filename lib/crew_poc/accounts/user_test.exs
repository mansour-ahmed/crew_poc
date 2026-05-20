defmodule CrewPoc.Accounts.UserTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Accounts.User

  setup do
    org = organization() |> generate()
    %{organization_id: org.id}
  end

  @valid_attrs %{
    email: "james@example.com",
    name: "James Okafor",
    job_title: "Operations Director",
    birthday: ~D[1985-03-15],
    started_at: ~D[2020-01-01]
  }

  describe "create/1" do
    test "given valid attrs, a user is created", %{organization_id: organization_id} do
      attrs = Map.put(@valid_attrs, :organization_id, organization_id)

      assert %User{email: "james@example.com", name: "James Okafor"} =
               User
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create!(authorize?: false)
    end

    test "given duplicate email, an error is raised", %{organization_id: organization_id} do
      attrs = Map.put(@valid_attrs, :organization_id, organization_id)

      User
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(authorize?: false)

      assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
        User
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.create!(authorize?: false)
      end
    end
  end

  describe "calculations" do
    test "given a user with today's birthday, birthday_today? is true", %{
      organization_id: organization_id
    } do
      today = Date.utc_today()

      user =
        [organization_id: organization_id, birthday: today]
        |> user()
        |> generate()

      loaded = Ash.load!(user, [:birthday_today?], authorize?: false)
      assert loaded.birthday_today? == true
    end

    test "given a user whose birthday is not today, birthday_today? is false", %{
      organization_id: organization_id
    } do
      tomorrow = Date.utc_today() |> Date.add(1)

      user =
        [organization_id: organization_id, birthday: tomorrow]
        |> user()
        |> generate()

      loaded = Ash.load!(user, [:birthday_today?], authorize?: false)
      assert loaded.birthday_today? == false
    end

    test "given a user whose work anniversary is today, work_anniversary_today? is true", %{
      organization_id: organization_id
    } do
      today = Date.utc_today()
      start_date = %{today | year: today.year - 2}

      user =
        [organization_id: organization_id, started_at: start_date]
        |> user()
        |> generate()

      loaded = Ash.load!(user, [:work_anniversary_today?], authorize?: false)

      assert loaded.work_anniversary_today? == true
    end

    test "given a user whose work anniversary is not today, work_anniversary_today? is false", %{
      organization_id: organization_id
    } do
      tomorrow = Date.utc_today() |> Date.add(1)
      start_date = %{tomorrow | year: tomorrow.year - 2}

      user =
        [organization_id: organization_id, started_at: start_date]
        |> user()
        |> generate()

      loaded = Ash.load!(user, [:work_anniversary_today?], authorize?: false)
      assert loaded.work_anniversary_today? == false
    end
  end
end

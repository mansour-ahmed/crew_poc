defmodule CrewPoc.Accounts.OrganizationTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Accounts.Organization

  @valid_attrs %{name: "Grand Pacific Hotels", slug: "grand-pacific-hotels"}

  describe "create/1" do
    test "given valid attrs, an organization is created" do
      assert %Organization{name: "Grand Pacific Hotels", slug: "grand-pacific-hotels"} =
               Organization
               |> Ash.Changeset.for_create(:create, @valid_attrs)
               |> Ash.create!(authorize?: false)
    end

    test "given no slug, slug is auto-generated from name" do
      assert %Organization{slug: "grand-pacific-hotels"} =
               Organization
               |> Ash.Changeset.for_create(:create, %{name: "Grand Pacific Hotels"})
               |> Ash.create!(authorize?: false)
    end

    test "given duplicate name, an error is raised" do
      Organization
      |> Ash.Changeset.for_create(:create, @valid_attrs)
      |> Ash.create!(authorize?: false)

      assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
        Organization
        |> Ash.Changeset.for_create(:create, @valid_attrs)
        |> Ash.create!(authorize?: false)
      end
    end
  end
end

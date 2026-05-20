defmodule CrewPoc.Venues.VenueTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Venues
  alias CrewPoc.Venues.Venue

  require Ash.Query

  @valid_attrs %{
    name: "Meridian Grand London",
    city: "London",
    timezone: "Europe/London"
  }

  describe "create_venue/1" do
    setup do
      organization = organization() |> generate()
      %{organization_id: organization.id}
    end

    test "given valid attrs, a venue is created with correct organization", %{
      organization_id: organization_id
    } do
      assert %{
               name: "Meridian Grand London",
               city: "London",
               timezone: "Europe/London",
               organization_id: ^organization_id
             } =
               @valid_attrs
               |> Map.put(:organization_id, organization_id)
               |> Venues.create_venue!()
    end

    test "given no slug, slug is auto-generated from name", %{organization_id: organization_id} do
      assert %{slug: "meridian-grand-london"} =
               @valid_attrs
               |> Map.put(:organization_id, organization_id)
               |> Venues.create_venue!()
    end

    test "given a slug, the provided slug is used", %{organization_id: organization_id} do
      attrs =
        @valid_attrs
        |> Map.put(:organization_id, organization_id)
        |> Map.put(:slug, "my-custom-slug")

      assert %{slug: "my-custom-slug"} = Venues.create_venue!(attrs)
    end

    test "given a name with special characters, slug is normalized", %{
      organization_id: organization_id
    } do
      attrs =
        @valid_attrs
        |> Map.put(:organization_id, organization_id)
        |> Map.put(:name, "Grand Spa -- Boutique!")

      assert %{slug: "grand-spa-boutique"} = Venues.create_venue!(attrs)
    end
  end

  describe "list_venues/1" do
    setup do
      organization = organization() |> generate()
      other_organization = organization() |> generate()
      %{organization_id: organization.id, other_organization_id: other_organization.id}
    end

    test "given venues in an org, returns all venues for that org", %{
      organization_id: organization_id
    } do
      venue1 =
        [organization_id: organization_id]
        |> venue()
        |> generate()

      venue2 =
        [organization_id: organization_id]
        |> venue()
        |> generate()

      result =
        Venue
        |> Ash.Query.filter(organization_id == ^organization_id)
        |> Ash.read!(authorize?: false)

      assert_lists_equal(Enum.map(result, & &1.id), [venue1.id, venue2.id])
    end

    test "given venues in another org, they are not returned when filtering by org", %{
      organization_id: organization_id,
      other_organization_id: other_organization_id
    } do
      [organization_id: other_organization_id]
      |> venue()
      |> generate()

      result =
        Venue
        |> Ash.Query.filter(organization_id == ^organization_id)
        |> Ash.read!(authorize?: false)

      assert Enum.empty?(result)
    end
  end
end

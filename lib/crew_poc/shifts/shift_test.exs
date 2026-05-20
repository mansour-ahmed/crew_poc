defmodule CrewPoc.Shifts.ShiftTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Shifts
  alias CrewPoc.Shifts.Shift

  require Ash.Query

  @valid_attrs %{
    name: "Friday evening front-desk",
    starts_at: ~U[2026-06-01 17:00:00Z],
    ends_at: ~U[2026-06-01 23:00:00Z]
  }

  setup do
    organization = organization() |> generate()

    venue =
      [organization_id: organization.id]
      |> venue()
      |> generate()

    %{organization_id: organization.id, venue_id: venue.id}
  end

  describe "create_shift/1" do
    test "given valid attrs, a shift is created", %{
      organization_id: organization_id,
      venue_id: venue_id
    } do
      assert %Shift{
               name: "Friday evening front-desk",
               starts_at: ~U[2026-06-01 17:00:00Z],
               ends_at: ~U[2026-06-01 23:00:00Z],
               organization_id: ^organization_id,
               venue_id: ^venue_id
             } =
               @valid_attrs
               |> Map.merge(%{organization_id: organization_id, venue_id: venue_id})
               |> Shifts.create_shift!()
    end
  end

  describe "validations" do
    test "given ends_at before starts_at, an error is raised", %{
      organization_id: organization_id,
      venue_id: venue_id
    } do
      attrs =
        Map.merge(@valid_attrs, %{
          organization_id: organization_id,
          venue_id: venue_id,
          starts_at: ~U[2026-06-01 23:00:00Z],
          ends_at: ~U[2026-06-01 17:00:00Z]
        })

      assert_raise Ash.Error.Invalid, ~r/ends_at must be after starts_at/, fn ->
        Shifts.create_shift!(attrs)
      end
    end

    test "given ends_at equal to starts_at, an error is raised", %{
      organization_id: organization_id,
      venue_id: venue_id
    } do
      attrs =
        Map.merge(@valid_attrs, %{
          organization_id: organization_id,
          venue_id: venue_id,
          starts_at: ~U[2026-06-01 17:00:00Z],
          ends_at: ~U[2026-06-01 17:00:00Z]
        })

      assert_raise Ash.Error.Invalid, ~r/ends_at must be after starts_at/, fn ->
        Shifts.create_shift!(attrs)
      end
    end
  end

  describe "check constraints" do
    test "given ends_at before starts_at via Ash.Seed, the DB rejects it", %{
      organization_id: organization_id,
      venue_id: venue_id
    } do
      assert_raise Ash.Error.Invalid, ~r/ends_at must be after starts_at/, fn ->
        Ash.Seed.seed!(Shift, %{
          name: "Broken shift",
          starts_at: ~U[2026-06-01 23:00:00Z],
          ends_at: ~U[2026-06-01 17:00:00Z],
          organization_id: organization_id,
          venue_id: venue_id
        })
      end
    end
  end

  describe "calculations" do
    test "given a shift in the future, status is :upcoming", %{
      organization_id: organization_id,
      venue_id: venue_id
    } do
      now = DateTime.utc_now()
      future_start = DateTime.add(now, 7, :day)
      future_end = DateTime.add(future_start, 6, :hour)

      shift =
        [
          organization_id: organization_id,
          venue_id: venue_id,
          starts_at: future_start,
          ends_at: future_end
        ]
        |> shift()
        |> generate()

      assert %{status: :upcoming} = Ash.load!(shift, :status, authorize?: false)
    end

    test "given a shift in the past, status is :finished", %{
      organization_id: organization_id,
      venue_id: venue_id
    } do
      now = DateTime.utc_now()
      past_start = DateTime.add(now, -2, :day)
      past_end = DateTime.add(now, -1, :day)

      shift =
        [
          organization_id: organization_id,
          venue_id: venue_id,
          starts_at: past_start,
          ends_at: past_end
        ]
        |> shift()
        |> generate()

      assert %{status: :finished} = Ash.load!(shift, :status, authorize?: false)
    end

    test "given a shift in progress, status is :active", %{
      organization_id: organization_id,
      venue_id: venue_id
    } do
      now = DateTime.utc_now()
      past_start = DateTime.add(now, -1, :hour)
      future_end = DateTime.add(now, 1, :hour)

      shift =
        [
          organization_id: organization_id,
          venue_id: venue_id,
          starts_at: past_start,
          ends_at: future_end
        ]
        |> shift()
        |> generate()

      assert %{status: :active} = Ash.load!(shift, :status, authorize?: false)
    end
  end
end

defmodule CrewPoc.Shifts.ShiftAssignmentTest do
  use CrewPoc.DataCase, async: true

  alias CrewPoc.Shifts
  alias CrewPoc.Shifts.ShiftAssignment

  require Ash.Query

  setup do
    organization = organization() |> generate()

    venue =
      [organization_id: organization.id]
      |> venue()
      |> generate()

    shift =
      [organization_id: organization.id, venue_id: venue.id]
      |> shift()
      |> generate()

    %{organization_id: organization.id, venue_id: venue.id, shift_id: shift.id}
  end

  describe "create_shift_assignment/1" do
    setup %{organization_id: organization_id, venue_id: venue_id} do
      user =
        [organization_id: organization_id]
        |> user()
        |> generate()

      [organization_id: organization_id, venue_id: venue_id, user_id: user.id]
      |> venue_membership()
      |> generate()

      %{user_id: user.id}
    end

    test "given valid attrs and existing venue membership, an assignment is created", %{
      organization_id: organization_id,
      shift_id: shift_id,
      user_id: user_id
    } do
      assert %ShiftAssignment{
               organization_id: ^organization_id,
               shift_id: ^shift_id,
               user_id: ^user_id
             } =
               Shifts.create_shift_assignment!(%{
                 organization_id: organization_id,
                 shift_id: shift_id,
                 user_id: user_id
               })
    end
  end

  describe "validations" do
    test "given a user without VenueMembership for the shift's venue, an error is raised", %{
      organization_id: organization_id,
      shift_id: shift_id
    } do
      user =
        [organization_id: organization_id]
        |> user()
        |> generate()

      assert_raise Ash.Error.Invalid, ~r/user must be a member of the shift's venue/, fn ->
        Shifts.create_shift_assignment!(%{
          organization_id: organization_id,
          shift_id: shift_id,
          user_id: user.id
        })
      end
    end

    test "given a duplicate user+shift pair, an error is raised", %{
      organization_id: organization_id,
      venue_id: venue_id,
      shift_id: shift_id
    } do
      user =
        [organization_id: organization_id]
        |> user()
        |> generate()

      [organization_id: organization_id, venue_id: venue_id, user_id: user.id]
      |> venue_membership()
      |> generate()

      Shifts.create_shift_assignment!(%{
        organization_id: organization_id,
        shift_id: shift_id,
        user_id: user.id
      })

      assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
        Shifts.create_shift_assignment!(%{
          organization_id: organization_id,
          shift_id: shift_id,
          user_id: user.id
        })
      end
    end
  end

  describe "destroy_shift_assignment/1" do
    test "given an existing assignment, it is destroyed", %{
      organization_id: organization_id,
      venue_id: venue_id,
      shift_id: shift_id
    } do
      assignment =
        [organization_id: organization_id, venue_id: venue_id, shift_id: shift_id]
        |> shift_assignment()
        |> generate()

      assert :ok = Shifts.destroy_shift_assignment!(assignment)

      refute ShiftAssignment
             |> Ash.Query.filter(id == ^assignment.id)
             |> Ash.exists?(authorize?: false)
    end
  end
end

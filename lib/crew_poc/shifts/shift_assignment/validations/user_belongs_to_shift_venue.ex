defmodule CrewPoc.Shifts.ShiftAssignment.Validations.UserBelongsToShiftVenue do
  @moduledoc """
  Validates that the assigned user already has a VenueMembership for the
  shift's venue. Enforced in the (seed-only) create action.
  """

  use Ash.Resource.Validation

  alias Ash.Changeset
  alias CrewPoc.Shifts.Shift

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    shift_id = Changeset.get_attribute(changeset, :shift_id)
    user_id = Changeset.get_attribute(changeset, :user_id)

    validate_membership(shift_id, user_id)
  end

  # Skip when either ID is missing — `allow_nil?: false` on the attributes reports that.
  defp validate_membership(nil, _user_id), do: :ok
  defp validate_membership(_shift_id, nil), do: :ok

  defp validate_membership(shift_id, user_id) do
    if shift_has_member?(shift_id, user_id),
      do: :ok,
      else: {:error, field: :user_id, message: "user must be a member of the shift's venue"}
  end

  defp shift_has_member?(shift_id, user_id) do
    Shift
    |> Ash.Query.filter(id == ^shift_id and exists(venue.venue_memberships, user_id == ^user_id))
    |> Ash.exists?(authorize?: false)
  end
end

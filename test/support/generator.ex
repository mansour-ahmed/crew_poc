defmodule CrewPoc.Generator do
  @moduledoc "Data generation for tests"

  use Ash.Generator

  @spec uniq() :: integer()
  defp uniq, do: System.unique_integer([:positive])

  #####################
  ### Organizations ###
  #####################

  @spec organization(keyword()) :: Ash.Generator.t()
  def organization(opts \\ []) do
    changeset_generator(
      CrewPoc.Accounts.Organization,
      :create,
      defaults: [
        name: sequence(:org_name, &"Org #{&1}"),
        slug: sequence(:org_slug, &"org-#{uniq()}-#{&1}")
      ],
      overrides: opts,
      authorize?: false
    )
  end

  #############
  ### Users ###
  #############

  @spec user(keyword()) :: Ash.Generator.t()
  def user(opts \\ []) do
    organization_id =
      opts[:organization_id] ||
        once(:default_organization_id, fn -> (organization() |> generate()).id end)

    changeset_generator(
      CrewPoc.Accounts.User,
      :create,
      defaults: [
        email: sequence(:user_email, &"user#{uniq()}-#{&1}@example.com"),
        name: sequence(:user_name, &"User #{&1}"),
        role: :staff,
        locale: "en",
        job_title: "Staff",
        birthday: ~D[1990-01-01],
        started_at: ~D[2024-01-01],
        organization_id: organization_id
      ],
      overrides: opts,
      authorize?: false
    )
  end

  ##############
  ### Venues ###
  ##############

  @spec venue(keyword()) :: Ash.Generator.t()
  def venue(opts \\ []) do
    organization_id =
      opts[:organization_id] ||
        once(:default_organization_id, fn -> (organization() |> generate()).id end)

    changeset_generator(
      CrewPoc.Venues.Venue,
      :create,
      defaults: [
        name: sequence(:venue_name, &"Venue #{&1}"),
        slug: sequence(:venue_slug, &"venue-#{uniq()}-#{&1}"),
        city: "London",
        timezone: "Europe/London",
        organization_id: organization_id
      ],
      overrides: opts,
      authorize?: false
    )
  end

  ########################
  ### Venue Memberships ##
  ########################

  @spec venue_membership(keyword()) :: Ash.Generator.t()
  def venue_membership(opts \\ []) do
    organization_id =
      opts[:organization_id] ||
        once(:default_organization_id, fn -> (organization() |> generate()).id end)

    changeset_generator(
      CrewPoc.Venues.VenueMembership,
      :create,
      defaults: [
        organization_id: organization_id,
        venue_id: opts[:venue_id] || (venue() |> generate()).id,
        user_id: opts[:user_id] || (user() |> generate()).id
      ],
      overrides: opts,
      authorize?: false
    )
  end

  ##############
  ### Shifts ###
  ##############

  @spec shift(keyword()) :: Ash.Generator.t()
  def shift(opts \\ []) do
    organization_id =
      opts[:organization_id] ||
        once(:default_organization_id, fn -> (organization() |> generate()).id end)

    venue_id =
      opts[:venue_id] ||
        ([organization_id: organization_id]
         |> venue()
         |> generate()).id

    changeset_generator(
      CrewPoc.Shifts.Shift,
      :create,
      defaults: [
        name: sequence(:shift_name, &"Shift #{&1}"),
        starts_at: ~U[2026-06-01 17:00:00Z],
        ends_at: ~U[2026-06-01 23:00:00Z],
        organization_id: organization_id,
        venue_id: venue_id
      ],
      overrides: opts,
      authorize?: false
    )
  end

  #########################
  ### Shift Assignments ###
  #########################

  @spec shift_assignment(keyword()) :: Ash.Generator.t()
  def shift_assignment(opts \\ []) do
    organization_id =
      opts[:organization_id] ||
        once(:default_organization_id, fn -> (organization() |> generate()).id end)

    {shift_id, venue_id} = resolve_shift_for_assignment(opts, organization_id)
    user_id = resolve_user_for_assignment(opts, organization_id, venue_id)

    changeset_generator(
      CrewPoc.Shifts.ShiftAssignment,
      :create,
      defaults: [
        organization_id: organization_id,
        shift_id: shift_id,
        user_id: user_id
      ],
      overrides: Keyword.drop(opts, [:venue_id]),
      authorize?: false
    )
  end

  defp resolve_shift_for_assignment(opts, organization_id) do
    cond do
      opts[:shift_id] && opts[:venue_id] ->
        {opts[:shift_id], opts[:venue_id]}

      opts[:shift_id] ->
        shift = Ash.get!(CrewPoc.Shifts.Shift, opts[:shift_id], authorize?: false)
        {shift.id, shift.venue_id}

      true ->
        venue_id =
          opts[:venue_id] ||
            ([organization_id: organization_id]
             |> venue()
             |> generate()).id

        shift =
          [organization_id: organization_id, venue_id: venue_id]
          |> shift()
          |> generate()

        {shift.id, venue_id}
    end
  end

  defp resolve_user_for_assignment(opts, organization_id, venue_id) do
    case opts[:user_id] do
      nil ->
        user_record =
          [organization_id: organization_id]
          |> user()
          |> generate()

        [organization_id: organization_id, venue_id: venue_id, user_id: user_record.id]
        |> venue_membership()
        |> generate()

        user_record.id

      user_id ->
        user_id
    end
  end
end

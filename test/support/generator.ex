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
end

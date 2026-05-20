defmodule CrewPoc.Venues do
  use Ash.Domain,
    otp_app: :crew_poc,
    extensions: [AshTypescript.Rpc]

  typescript_rpc do
    resource CrewPoc.Venues.Venue do
      rpc_action :list_venues, :read
    end

    resource CrewPoc.Venues.VenueMembership do
      rpc_action :list_venue_memberships, :read
    end
  end

  resources do
    resource CrewPoc.Venues.Venue do
      define :list_venues, action: :read
      define :get_venue, action: :read, get_by: [:id]
      define :create_venue, action: :create
    end

    resource CrewPoc.Venues.VenueMembership do
      define :list_venue_memberships, action: :read
      define :create_venue_membership, action: :create
      define :destroy_venue_membership, action: :destroy
    end
  end
end

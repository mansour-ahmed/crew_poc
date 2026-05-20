defmodule CrewPoc.Recognition do
  use Ash.Domain,
    otp_app: :crew_poc,
    extensions: [AshTypescript.Rpc]

  typescript_rpc do
    resource CrewPoc.Recognition.Shoutout do
      rpc_action :list_shoutouts, :read
      rpc_action :create_shoutout, :create
      rpc_action :search_shoutouts, :search
    end
  end

  resources do
    resource CrewPoc.Recognition.Shoutout do
      define :create_shoutout, action: :create
      define :get_shoutout, action: :read, get_by: [:id]
      define :list_shoutouts, action: :read
      define :search_shoutouts, action: :search, args: [:query]
    end
  end
end

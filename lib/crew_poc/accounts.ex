defmodule CrewPoc.Accounts do
  use Ash.Domain,
    otp_app: :crew_poc,
    extensions: [AshTypescript.Rpc]

  typescript_rpc do
    resource CrewPoc.Accounts.Organization do
      rpc_action :get_organization, :read
    end

    resource CrewPoc.Accounts.User do
      rpc_action :list_users, :read
      rpc_action :get_user, :read
      rpc_action :get_current_user, :get_current_user
      rpc_action :celebrating_today, :celebrating_today
    end
  end

  resources do
    resource CrewPoc.Accounts.Organization do
      define :get_organization, action: :read, get_by: [:id]
      define :create_organization, action: :create
    end

    resource CrewPoc.Accounts.User do
      define :celebrating_today, action: :celebrating_today
      define :create_user, action: :create
      define :get_current_user, action: :get_current_user
      define :get_user, action: :read, get_by: [:id]
      define :list_users, action: :read
    end
  end
end

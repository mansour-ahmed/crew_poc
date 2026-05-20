defmodule CrewPoc.Shifts do
  use Ash.Domain,
    otp_app: :crew_poc,
    extensions: [AshTypescript.Rpc]

  typescript_rpc do
    resource CrewPoc.Shifts.Shift do
      rpc_action :list_shifts, :read
    end

    resource CrewPoc.Shifts.ShiftAssignment do
      rpc_action :list_shift_assignments, :read
    end
  end

  resources do
    resource CrewPoc.Shifts.Shift do
      define :create_shift, action: :create
      define :get_shift, action: :read, get_by: [:id]
      define :list_shifts, action: :read
    end

    resource CrewPoc.Shifts.ShiftAssignment do
      define :create_shift_assignment, action: :create
      define :destroy_shift_assignment, action: :destroy
      define :list_shift_assignments, action: :read
    end
  end
end

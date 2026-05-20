defmodule CrewPoc.Repo.Migrations.AddOrganizationCascadeDeletes do
  @moduledoc """
  Switches the `organization_id` foreign key on every org-scoped table to
  `on_delete: :delete_all` so deleting an organization cascades to all of its
  data.
  """

  use Ecto.Migration

  @org_scoped_tables [
    :venues,
    :users,
    :shifts,
    :shift_assignments,
    :conversations,
    :messages
  ]

  def up do
    for table <- @org_scoped_tables do
      fkey = "#{table}_organization_id_fkey"

      drop constraint(table, fkey)

      alter table(table) do
        modify :organization_id,
               references(:organizations,
                 column: :id,
                 name: fkey,
                 type: :uuid,
                 prefix: "public",
                 on_delete: :delete_all
               )
      end
    end
  end

  def down do
    for table <- @org_scoped_tables do
      fkey = "#{table}_organization_id_fkey"

      drop constraint(table, fkey)

      alter table(table) do
        modify :organization_id,
               references(:organizations,
                 column: :id,
                 name: fkey,
                 type: :uuid,
                 prefix: "public"
               )
      end
    end
  end
end

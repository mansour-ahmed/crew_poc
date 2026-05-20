defmodule CrewPoc.Accounts.User do
  use Ash.Resource,
    domain: CrewPoc.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "users"
    repo CrewPoc.Repo
  end

  typescript do
    type_name "User"
  end

  resource do
    description "A staff member."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:email, :name, :organization_id, :role, :locale, :job_title, :birthday, :started_at]
    end

    read :celebrating_today do
      filter expr(birthday_today? == true or work_anniversary_today? == true)
    end

    read :get_current_user do
      get? true
      filter expr(id == ^actor(:id))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :organization_id, :uuid, allow_nil?: false, public?: true

    attribute :role, :atom do
      constraints one_of: [:admin, :manager, :staff]
      default :staff
      allow_nil? false
      public? true
    end

    attribute :locale, :string, allow_nil?: false, default: "en", public?: true

    attribute :job_title, :string, allow_nil?: false, public?: true
    attribute :birthday, :date, allow_nil?: false, public?: true
    attribute :started_at, :date, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      attribute_writable?: true,
      define_attribute?: false
  end

  calculations do
    calculate :birthday_today?,
              :boolean,
              expr(
                not is_nil(birthday) and
                  fragment("EXTRACT(MONTH FROM ?)::int", birthday) ==
                    fragment("EXTRACT(MONTH FROM CURRENT_DATE)::int") and
                  fragment("EXTRACT(DAY FROM ?)::int", birthday) ==
                    fragment("EXTRACT(DAY FROM CURRENT_DATE)::int")
              )

    calculate :work_anniversary_today?,
              :boolean,
              expr(
                fragment("EXTRACT(MONTH FROM ?)::int", started_at) ==
                  fragment("EXTRACT(MONTH FROM CURRENT_DATE)::int") and
                  fragment("EXTRACT(DAY FROM ?)::int", started_at) ==
                    fragment("EXTRACT(DAY FROM CURRENT_DATE)::int") and
                  fragment("DATE_PART('year', AGE(CURRENT_DATE, ?))", started_at) > 0
              )
  end

  identities do
    identity :unique_email, [:email]
  end
end

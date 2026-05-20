defmodule CrewPoc.Feed.PostTranslation do
  use Ash.Resource,
    domain: CrewPoc.Feed,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAi],
    authorizers: [Ash.Policy.Authorizer]

  alias CrewPoc.Feed.TranslatedPost

  postgres do
    table "post_translations"
    repo CrewPoc.Repo

    references do
      reference :organization, on_delete: :delete
      reference :post, on_delete: :delete
    end
  end

  resource do
    description "Cached LLM translation of a Post's title and body."
  end

  actions do
    defaults [:read]

    create :create do
      accept [:organization_id, :post_id, :target_locale, :title, :body]
    end

    action :translate, TranslatedPost do
      argument :title, :string, allow_nil?: false
      argument :body, :string, allow_nil?: false
      argument :source_locale, :string, allow_nil?: false
      argument :target_locale, :string, allow_nil?: false

      run prompt("openai:gpt-4o-mini",
            prompt: """
            Translate the following announcement from <%= @input.arguments.source_locale %> to <%= @input.arguments.target_locale %>.
            Return the translated title and body. Do not add commentary, quotes, or labels.

            Title: <%= @input.arguments.title %>
            Body: <%= @input.arguments.body %>
            """,
            tools: false
          )
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action(:translate) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid, allow_nil?: false, public?: true
    attribute :post_id, :uuid, allow_nil?: false, public?: true
    attribute :target_locale, :string, allow_nil?: false, public?: true
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, CrewPoc.Accounts.Organization,
      attribute_writable?: true,
      define_attribute?: false

    belongs_to :post, CrewPoc.Feed.Post,
      attribute_writable?: true,
      define_attribute?: false
  end

  identities do
    identity :unique_post_target_locale, [:post_id, :target_locale]
  end
end

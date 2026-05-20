defmodule CrewPoc.Feed do
  use Ash.Domain,
    otp_app: :crew_poc,
    extensions: [AshTypescript.Rpc]

  typescript_rpc do
    resource CrewPoc.Feed.Post do
      rpc_action :list_posts, :read
      rpc_action :create_post, :create
      rpc_action :search_posts, :search
    end

    resource CrewPoc.Feed.Acknowledgement do
      rpc_action :create_acknowledgement, :create
    end

    resource CrewPoc.Feed.PostTranslation do
      rpc_action :ensure_post_translation, :ensure_for
    end
  end

  resources do
    resource CrewPoc.Feed.Post do
      define :create_post, action: :create
      define :get_post, action: :read, get_by: [:id]
      define :list_posts, action: :read
      define :search_posts, action: :search, args: [:query]
    end

    resource CrewPoc.Feed.PostTranslation do
      define :ensure_post_translation,
        action: :ensure_for,
        args: [:post_id, :target_locale]
    end

    resource CrewPoc.Feed.Acknowledgement do
      define :create_acknowledgement, action: :create, args: [:post_id]
      define :list_acknowledgements, action: :read
    end
  end
end

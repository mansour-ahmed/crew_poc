defmodule CrewPocWeb.Router do
  use CrewPocWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_root_layout, html: {CrewPocWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug CrewPocWeb.Plugs.CurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", CrewPocWeb do
    pipe_through :browser

    post "/switch_user", CurrentUserController, :switch_user
  end

  scope "/", CrewPocWeb do
    pipe_through :browser

    post "/rpc/run", AshTypescriptRpcController, :run
    post "/rpc/validate", AshTypescriptRpcController, :validate

    # Everything else is handled by the React SPA's BrowserRouter.
    get "/*path", PageController, :index
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:crew_poc, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:crew_poc, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end

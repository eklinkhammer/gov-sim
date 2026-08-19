defmodule GovSimWeb.Router do
  use GovSimWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GovSimWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GovSimWeb do
    pipe_through :browser

    live "/", SimulationLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", GovSimWeb do
  #   pipe_through :api
  # end
end

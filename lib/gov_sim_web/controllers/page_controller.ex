defmodule GovSimWeb.PageController do
  use GovSimWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

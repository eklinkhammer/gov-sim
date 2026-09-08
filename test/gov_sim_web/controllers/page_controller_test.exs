defmodule GovSimWeb.PageControllerTest do
  use GovSimWeb.ConnCase

  test "GET / renders the simulation dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "GovSim: Medieval Village"
  end
end

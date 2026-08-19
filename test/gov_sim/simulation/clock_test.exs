defmodule GovSim.Simulation.ClockTest do
  use ExUnit.Case, async: true

  alias GovSim.Simulation.Clock

  test "to_date converts minute 0 to March 1 00:00" do
    assert Clock.to_date(0) == {3, 1, 0, 0}
  end

  test "to_date handles dawn on day 0" do
    assert Clock.to_date(360) == {3, 1, 6, 0}
  end

  test "to_date rolls over to April" do
    # March has 31 days: 31 * 1440 = 44640 minutes
    assert Clock.to_date(44640) == {4, 1, 0, 0}
  end

  test "format produces readable string" do
    assert Clock.format(0) == "March 1, 00:00"
    assert Clock.format(360) == "March 1, 06:00"
  end

  test "dawn returns 6:00 for given day" do
    assert Clock.dawn(0) == 360
    assert Clock.dawn(1) == 1440 + 360
  end

  test "day_number extracts day from sim_time" do
    assert Clock.day_number(0) == 0
    assert Clock.day_number(1439) == 0
    assert Clock.day_number(1440) == 1
  end

  test "from_date round-trips with to_date" do
    time = Clock.from_date(5, 15, 12, 30)
    assert Clock.to_date(time) == {5, 15, 12, 30}
  end
end

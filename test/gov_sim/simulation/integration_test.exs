defmodule GovSim.Simulation.IntegrationTest do
  use ExUnit.Case

  alias GovSim.Simulation.Engine
  alias GovSim.World.World
  alias GovSim.Entities.Inventory

  @moduletag :integration

  test "with 8 bushels, family starves before harvest — death occurs" do
    Engine.reset()
    Engine.step(3000)

    state = Engine.get_state()
    world = state.world

    # With only 8 bushels (~49 days of food) and 120-day growth season,
    # the family will starve before harvest
    death_events = Enum.filter(world.event_log, &(&1.type == :death))
    starvation_events = Enum.filter(world.event_log, &(&1.type == :starvation))

    assert length(starvation_events) > 0, "Expected starvation events"
    assert length(death_events) > 0, "Expected at least one death from starvation"

    # At least one person should be dead
    dead = world.persons |> Map.values() |> Enum.count(&(not &1.alive))
    assert dead > 0, "Expected at least one dead person"
  end

  test "hunger system consumes grain over time" do
    Engine.reset()
    Engine.step(100)

    state = Engine.get_state()
    household = World.get_household(state.world, :household_1)
    grain = Inventory.get(household.inventory, :wheat_bushels)

    assert grain < 8.0,
           "Expected some grain consumption. Still at #{grain} bushels."
  end

  test "persons experience hunger that rises and falls with eating" do
    Engine.reset()
    Engine.step(50)

    state = Engine.get_state()

    eat_events =
      Enum.filter(state.world.event_log, fn entry ->
        entry.type == :person_try_eat
      end)

    assert length(eat_events) > 0, "Expected person_try_eat events in the log"
  end

  test "planting occurs as visible labor with social delegation" do
    Engine.reset()
    Engine.step(20)

    state = Engine.get_state()
    log_types = Enum.map(state.world.event_log, & &1.type)

    assert :plant_begin in log_types, "Expected plant_begin events"
    assert :request_work in log_types, "Expected Edmund to delegate planting"
  end
end

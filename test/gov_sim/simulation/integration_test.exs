defmodule GovSim.Simulation.IntegrationTest do
  use ExUnit.Case

  alias GovSim.Simulation.Engine
  alias GovSim.World.World
  alias GovSim.Entities.Inventory

  @moduletag :integration

  test "with 8 bushels, player family starves before harvest — death occurs" do
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

    # At least one person should be dead (across both households)
    dead = world.persons |> Map.values() |> Enum.count(&(not &1.alive))
    assert dead > 0, "Expected at least one dead person"
  end

  test "hunger system consumes grain over time in both households" do
    Engine.reset()
    Engine.step(100)

    state = Engine.get_state()
    household_1 = World.get_household(state.world, :household_1)
    household_2 = World.get_household(state.world, :household_2)
    grain_1 = Inventory.get(household_1.inventory, :wheat_bushels)
    grain_2 = Inventory.get(household_2.inventory, :wheat_bushels)

    assert grain_1 < 8.0,
           "Expected player household grain consumption. Still at #{grain_1} bushels."

    assert grain_2 < 10.0,
           "Expected AI household grain consumption. Still at #{grain_2} bushels."
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

  test "AI household (Aldric) plants autonomously" do
    Engine.reset()
    Engine.step(20)

    state = Engine.get_state()
    log_types = Enum.map(state.world.event_log, & &1.type)

    assert :plant_begin in log_types, "Expected plant_begin events from AI household"
    assert :person_assess_fields in log_types, "Expected Aldric to assess fields"
  end

  test "player household does NOT get automatic field assessment" do
    Engine.reset()
    Engine.step(20)

    state = Engine.get_state()

    assess_events =
      Enum.filter(state.world.event_log, fn entry ->
        entry.type == :person_assess_fields
      end)

    # Only AI household heads should have assessment events
    assessed_names = Enum.map(assess_events, fn e -> e.message end)

    refute Enum.any?(assessed_names, &String.contains?(&1, "Edmund")),
           "Edmund (player head) should not get automatic field assessment"
  end

  test "two households exist with correct setup" do
    Engine.reset()
    state = Engine.get_state()
    world = state.world

    assert Map.has_key?(world.households, :household_1)
    assert Map.has_key?(world.households, :household_2)

    hh1 = World.get_household(world, :household_1)
    hh2 = World.get_household(world, :household_2)

    assert hh1.head_id == :edmund
    assert hh2.head_id == :aldric
    assert length(hh1.member_ids) == 3
    assert length(hh2.member_ids) == 2

    assert world.player_household_id == :household_1
  end

  test "inject_event adds player command to queue" do
    Engine.reset()

    event = GovSim.Events.Event.new(0, :player_command_plant, nil, %{
      parcel_id: :field_north,
      person_id: :edmund
    })

    Engine.inject_event(event)
    Engine.step()

    state = Engine.get_state()

    player_events =
      Enum.filter(state.world.event_log, fn entry ->
        entry.type == :player_command
      end)

    assert length(player_events) > 0, "Expected player command log entry"
  end
end

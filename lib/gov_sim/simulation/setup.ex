defmodule GovSim.Simulation.Setup do
  @moduledoc """
  Initial world setup: Edmund's household with Thomas and Agnes,
  two wheat fields, 8 bushels starting grain.
  """

  alias GovSim.Entities.{Person, Parcel, Household, Inventory}
  alias GovSim.World.World
  alias GovSim.Simulation.{EventQueue, Clock}
  alias GovSim.Events.Event

  def initial_state do
    world = build_world()
    queue = build_initial_events()
    {world, queue}
  end

  defp build_world do
    edmund =
      Person.new(
        id: :edmund,
        name: "Edmund",
        age: 35,
        household_id: :household_1,
        labor_capacity: 1.0,
        energy: 1.0,
        hunger: 0.0,
        personality: %{industriousness: 0.8, obedience: 0.5},
        relationships: %{thomas: :child, agnes: :child}
      )

    thomas =
      Person.new(
        id: :thomas,
        name: "Thomas",
        age: 14,
        household_id: :household_1,
        labor_capacity: 0.7,
        energy: 1.0,
        hunger: 0.0,
        personality: %{industriousness: 0.5, obedience: 0.7},
        relationships: %{edmund: :parent, agnes: :sibling}
      )

    agnes =
      Person.new(
        id: :agnes,
        name: "Agnes",
        age: 10,
        household_id: :household_1,
        labor_capacity: 0.4,
        energy: 1.0,
        hunger: 0.0,
        personality: %{industriousness: 0.4, obedience: 0.85},
        relationships: %{edmund: :parent, thomas: :sibling}
      )

    field_north =
      Parcel.new(
        id: :field_north,
        household_id: :household_1,
        name: "North Field",
        acres: 5.0
      )

    field_south =
      Parcel.new(
        id: :field_south,
        household_id: :household_1,
        name: "South Field",
        acres: 5.0
      )

    household =
      Household.new(
        id: :household_1,
        name: "Edmund's Household",
        head_id: :edmund,
        member_ids: [:edmund, :thomas, :agnes],
        parcel_ids: [:field_north, :field_south],
        inventory: Inventory.new(%{wheat_bushels: 8.0})
      )

    %World{
      persons: %{
        edmund: edmund,
        thomas: thomas,
        agnes: agnes
      },
      parcels: %{
        field_north: field_north,
        field_south: field_south
      },
      households: %{
        household_1: household
      },
      event_log: [],
      sim_time: 0
    }
  end

  defp build_initial_events do
    dawn_time = Clock.dawn(0)

    events = [
      # First dawn — Edmund will assess fallow fields and decide to plant
      Event.new(dawn_time, :daily_dawn)
    ]

    EventQueue.new(events)
  end
end

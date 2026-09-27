defmodule GovSim.Simulation.Setup do
  @moduledoc """
  Initial world setup: two households.
  Player household (Edmund, Thomas, Agnes) — 2 wheat fields, 8 bushels.
  AI household (Aldric, Matilda) — 2 wheat fields, 10 bushels.
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
    # -- Player Household (Edmund) --
    edmund =
      Person.new(
        id: :edmund,
        name: "Edmund",
        age: 35,
        sex: :male,
        household_id: :household_1,
        labor_capacity: 1.0,
        energy: 1.0,
        hunger: 0.0,
        personality: %{industriousness: 0.8, obedience: 0.5},
        relationships: %{thomas: :child, agnes: :child, aldric: :stranger, matilda: :stranger}
      )

    thomas =
      Person.new(
        id: :thomas,
        name: "Thomas",
        age: 14,
        sex: :male,
        household_id: :household_1,
        labor_capacity: 0.7,
        energy: 1.0,
        hunger: 0.0,
        personality: %{industriousness: 0.5, obedience: 0.7},
        relationships: %{edmund: :parent, agnes: :sibling, aldric: :stranger, matilda: :stranger}
      )

    agnes =
      Person.new(
        id: :agnes,
        name: "Agnes",
        age: 10,
        sex: :female,
        household_id: :household_1,
        labor_capacity: 0.4,
        energy: 1.0,
        hunger: 0.0,
        personality: %{industriousness: 0.4, obedience: 0.85},
        relationships: %{edmund: :parent, thomas: :sibling, aldric: :stranger, matilda: :stranger}
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

    household_1 =
      Household.new(
        id: :household_1,
        name: "Edmund's Household",
        head_id: :edmund,
        member_ids: [:edmund, :thomas, :agnes],
        parcel_ids: [:field_north, :field_south],
        inventory: Inventory.new(%{wheat_bushels: 8.0})
      )

    # -- AI Household (Aldric) --
    aldric =
      Person.new(
        id: :aldric,
        name: "Aldric",
        age: 40,
        sex: :male,
        household_id: :household_2,
        labor_capacity: 1.0,
        energy: 1.0,
        hunger: 0.0,
        personality: %{industriousness: 0.6, obedience: 0.5},
        relationships: %{matilda: :child, edmund: :stranger, thomas: :stranger, agnes: :stranger}
      )

    matilda =
      Person.new(
        id: :matilda,
        name: "Matilda",
        age: 16,
        sex: :female,
        household_id: :household_2,
        labor_capacity: 0.8,
        energy: 1.0,
        hunger: 0.0,
        personality: %{industriousness: 0.5, obedience: 0.6},
        relationships: %{aldric: :parent, edmund: :stranger, thomas: :stranger, agnes: :stranger}
      )

    field_east =
      Parcel.new(
        id: :field_east,
        household_id: :household_2,
        name: "East Field",
        acres: 4.0
      )

    field_west =
      Parcel.new(
        id: :field_west,
        household_id: :household_2,
        name: "West Field",
        acres: 4.0
      )

    household_2 =
      Household.new(
        id: :household_2,
        name: "Aldric's Household",
        head_id: :aldric,
        member_ids: [:aldric, :matilda],
        parcel_ids: [:field_east, :field_west],
        inventory: Inventory.new(%{wheat_bushels: 10.0})
      )

    %World{
      persons: %{
        edmund: edmund,
        thomas: thomas,
        agnes: agnes,
        aldric: aldric,
        matilda: matilda
      },
      parcels: %{
        field_north: field_north,
        field_south: field_south,
        field_east: field_east,
        field_west: field_west
      },
      households: %{
        household_1: household_1,
        household_2: household_2
      },
      event_log: [],
      sim_time: 0,
      player_household_id: :household_1,
      player_avatar_id: :edmund
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

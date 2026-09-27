defmodule GovSim.World.World do
  @moduledoc """
  Top-level world state: maps of all entities + event log.
  Immutable struct passed through handlers.
  """

  alias GovSim.Entities.{Person, Parcel, Household}

  defstruct persons: %{},
            parcels: %{},
            households: %{},
            event_log: [],
            sim_time: 0,
            player_household_id: nil,
            player_avatar_id: nil,
            game_over: false

  @type t :: %__MODULE__{
          persons: %{atom() => Person.t()},
          parcels: %{atom() => Parcel.t()},
          households: %{atom() => Household.t()},
          event_log: list(),
          sim_time: integer(),
          player_household_id: atom() | nil,
          player_avatar_id: atom() | nil,
          game_over: boolean()
        }

  # Player avatar
  def player_avatar(%__MODULE__{player_avatar_id: nil}), do: nil
  def player_avatar(%__MODULE__{player_avatar_id: id} = world), do: get_person(world, id)

  # Person accessors
  def get_person(%__MODULE__{persons: persons}, id), do: Map.get(persons, id)

  def put_person(%__MODULE__{persons: persons} = world, %Person{id: id} = person) do
    %{world | persons: Map.put(persons, id, person)}
  end

  def update_person(%__MODULE__{} = world, id, fun) do
    case get_person(world, id) do
      nil -> world
      person -> put_person(world, fun.(person))
    end
  end

  # Parcel accessors
  def get_parcel(%__MODULE__{parcels: parcels}, id), do: Map.get(parcels, id)

  def put_parcel(%__MODULE__{parcels: parcels} = world, %Parcel{id: id} = parcel) do
    %{world | parcels: Map.put(parcels, id, parcel)}
  end

  def update_parcel(%__MODULE__{} = world, id, fun) do
    case get_parcel(world, id) do
      nil -> world
      parcel -> put_parcel(world, fun.(parcel))
    end
  end

  # Household accessors
  def get_household(%__MODULE__{households: households}, id), do: Map.get(households, id)

  def put_household(%__MODULE__{households: households} = world, %Household{id: id} = hh) do
    %{world | households: Map.put(households, id, hh)}
  end

  def update_household(%__MODULE__{} = world, id, fun) do
    case get_household(world, id) do
      nil -> world
      hh -> put_household(world, fun.(hh))
    end
  end

  # Event log
  def log_event(%__MODULE__{event_log: log} = world, entry) do
    %{world | event_log: [entry | log]}
  end

  def recent_events(%__MODULE__{event_log: log}, count \\ 50) do
    Enum.take(log, count)
  end

  # Queries
  def household_members(%__MODULE__{} = world, household_id) do
    case get_household(world, household_id) do
      nil ->
        []

      hh ->
        Enum.map(hh.member_ids, &get_person(world, &1))
        |> Enum.reject(&is_nil/1)
    end
  end

  def household_parcels(%__MODULE__{} = world, household_id) do
    case get_household(world, household_id) do
      nil ->
        []

      hh ->
        Enum.map(hh.parcel_ids, &get_parcel(world, &1))
        |> Enum.reject(&is_nil/1)
    end
  end

  def parcels_needing_harvest(%__MODULE__{} = world, household_id) do
    household_parcels(world, household_id)
    |> Enum.filter(&Parcel.needs_harvest?/1)
  end
end

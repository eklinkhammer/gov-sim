defmodule GovSim.Events.Handlers.Player do
  @moduledoc """
  Handlers for player commands: plant, harvest, request_labor.
  Validates ownership, availability, and parcel state before dispatching.
  """

  @behaviour GovSim.Events.Handler

  alias GovSim.Events.Event
  alias GovSim.World.World
  alias GovSim.Entities.{Person, Parcel}
  alias GovSim.Systems.Agriculture, as: AgriSystem

  @impl true
  def handle(%Event{type: :player_command_plant, time: time, payload: payload}, world) do
    world = %{world | sim_time: time}
    %{parcel_id: parcel_id, person_id: person_id} = payload

    with {:ok, person, parcel, _hh} <- validate_command(world, person_id, parcel_id),
         :ok <- validate_parcel_state(parcel, :fallow),
         :ok <- validate_planting_season(time) do
      log = %{
        time: time, type: :player_command, system: :player,
        message: "[YOU] Command: #{person.name} to plant #{parcel.name}."
      }

      event = Event.new(time + 1, :plant_begin, person_id, %{parcel_id: parcel_id})
      {World.log_event(world, log), [event]}
    else
      {:error, reason} ->
        log = %{
          time: time, type: :player_command, system: :player,
          message: "[YOU] Command failed: #{reason}"
        }

        {World.log_event(world, log), []}
    end
  end

  def handle(%Event{type: :player_command_harvest, time: time, payload: payload}, world) do
    world = %{world | sim_time: time}
    %{parcel_id: parcel_id, person_id: person_id} = payload

    with {:ok, person, parcel, _hh} <- validate_command(world, person_id, parcel_id),
         :ok <- validate_parcel_state(parcel, :ready) do
      log = %{
        time: time, type: :player_command, system: :player,
        message: "[YOU] Command: #{person.name} to harvest #{parcel.name}."
      }

      event = Event.new(time + 1, :harvest_begin, person_id, %{parcel_id: parcel_id})
      {World.log_event(world, log), [event]}
    else
      {:error, reason} ->
        log = %{
          time: time, type: :player_command, system: :player,
          message: "[YOU] Command failed: #{reason}"
        }

        {World.log_event(world, log), []}
    end
  end

  def handle(%Event{type: :player_command_request_labor, time: time, payload: payload}, world) do
    world = %{world | sim_time: time}
    %{target_id: target_id, parcel_id: parcel_id, task: task} = payload
    player_hh_id = world.player_household_id
    player_hh = World.get_household(world, player_hh_id)
    target = World.get_person(world, target_id)

    cond do
      target == nil or not Person.alive?(target) ->
        log = %{
          time: time, type: :player_command, system: :player,
          message: "[YOU] Command failed: target not available."
        }
        {World.log_event(world, log), []}

      Person.busy?(target) ->
        log = %{
          time: time, type: :player_command, system: :player,
          message: "[YOU] Command failed: #{target.name} is busy."
        }
        {World.log_event(world, log), []}

      true ->
        requester_id = player_hh.head_id

        log = %{
          time: time, type: :player_command, system: :player,
          message: "[YOU] Command: request #{target.name} to #{task} #{World.get_parcel(world, parcel_id).name}."
        }

        event = Event.new(time + 1, :request_work, requester_id, %{
          target_id: target_id,
          parcel_id: parcel_id,
          task: task
        })

        {World.log_event(world, log), [event]}
    end
  end

  # Validation helpers

  defp validate_command(world, person_id, parcel_id) do
    person = World.get_person(world, person_id)
    parcel = World.get_parcel(world, parcel_id)
    player_hh_id = world.player_household_id

    cond do
      person == nil or not Person.alive?(person) ->
        {:error, "person not available"}

      Person.busy?(person) ->
        {:error, "#{person.name} is busy"}

      parcel == nil ->
        {:error, "parcel not found"}

      parcel.household_id != player_hh_id ->
        {:error, "parcel not owned by your household"}

      person.household_id != player_hh_id ->
        {:error, "#{person.name} is not in your household"}

      true ->
        {:ok, person, parcel, World.get_household(world, player_hh_id)}
    end
  end

  defp validate_parcel_state(%Parcel{state: expected}, expected), do: :ok
  defp validate_parcel_state(%Parcel{state: actual}, expected) do
    {:error, "field is #{actual}, expected #{expected}"}
  end

  defp validate_planting_season(time) do
    if AgriSystem.planting_season?(time), do: :ok, else: {:error, "not planting season"}
  end
end

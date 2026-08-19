defmodule GovSim.Events.Handlers.Labor do
  @moduledoc """
  Handlers for person_assess_fields, plant_begin/complete,
  harvest_begin/complete, work_begin/complete.
  """

  @behaviour GovSim.Events.Handler

  alias GovSim.Events.Event
  alias GovSim.World.World
  alias GovSim.Systems.Agriculture, as: AgriSystem
  alias GovSim.Entities.Person

  @impl true
  def handle(%Event{type: :person_assess_fields, time: time, entity_id: person_id}, world) do
    world = %{world | sim_time: time}
    person = World.get_person(world, person_id)

    if person == nil or not person.alive do
      {world, []}
    else
      household = World.get_household(world, person.household_id)
      parcels = World.household_parcels(world, household.id)

      fallow_parcels =
        if AgriSystem.planting_season?(time) do
          Enum.filter(parcels, fn p -> p.state == :fallow end)
        else
          []
        end

      ready_parcels = Enum.filter(parcels, &GovSim.Entities.Parcel.needs_harvest?/1)

      # All actionable parcels: fallow (need planting) + ready (need harvesting)
      work_items =
        Enum.map(fallow_parcels, fn p -> {:plant, p} end) ++
          Enum.map(ready_parcels, fn p -> {:harvest, p} end)

      if Enum.empty?(work_items) do
        {world, []}
      else
        members =
          World.household_members(world, household.id)
          |> Enum.filter(&Person.alive?/1)
          |> Enum.reject(&Person.busy?/1)

        {events, _} =
          Enum.reduce(work_items, {[], members}, fn {task, parcel}, {evts, available} ->
            case available do
              [] ->
                {evts, []}

              [worker | rest] ->
                if worker.id == person_id do
                  # Head works directly
                  begin_type = if task == :plant, do: :plant_begin, else: :harvest_begin
                  evt = Event.new(time + 10, begin_type, worker.id, %{parcel_id: parcel.id})
                  {[evt | evts], rest}
                else
                  # Request another member to work
                  evt =
                    Event.new(time + 5, :request_work, person_id, %{
                      target_id: worker.id,
                      parcel_id: parcel.id,
                      task: task
                    })

                  {[evt | evts], rest}
                end
            end
          end)

        plant_count = length(fallow_parcels)
        harvest_count = length(ready_parcels)

        parts =
          [
            if(plant_count > 0, do: "#{plant_count} need planting"),
            if(harvest_count > 0, do: "#{harvest_count} ready for harvest")
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(", ")

        log_entry = %{
          time: time,
          type: :person_assess_fields,
          system: :labor,
          message: "#{person.name} surveys the fields: #{parts}."
        }

        {World.log_event(world, log_entry), events}
      end
    end
  end

  # -- Planting --

  def handle(%Event{type: :plant_begin, time: time, entity_id: person_id, payload: payload}, world) do
    world = %{world | sim_time: time}
    parcel_id = payload.parcel_id
    person = World.get_person(world, person_id)
    parcel = World.get_parcel(world, parcel_id)

    if person == nil or parcel == nil do
      {world, []}
    else
      labor = Person.effective_labor(person)
      duration = AgriSystem.plant_duration(parcel.acres, labor)

      world =
        world
        |> World.update_person(person_id, fn p ->
          %{p | current_task: %{type: :planting, parcel_id: parcel_id, started_at: time}}
        end)
        |> World.update_parcel(parcel_id, fn p -> %{p | state: :planting} end)

      complete_event =
        Event.new(time + duration, :plant_complete, person_id, %{
          parcel_id: parcel_id,
          crop: :wheat
        })

      log_entry = %{
        time: time,
        type: :plant_begin,
        system: :labor,
        message:
          "#{person.name} begins planting wheat on #{parcel.name} (#{parcel.acres} acres, est. #{div(duration, 60)} hours)."
      }

      {World.log_event(world, log_entry), [complete_event]}
    end
  end

  def handle(%Event{type: :plant_complete, time: time, entity_id: person_id, payload: payload}, world) do
    world = %{world | sim_time: time}
    parcel_id = payload.parcel_id
    crop = Map.get(payload, :crop, :wheat)
    person = World.get_person(world, person_id)

    if person == nil do
      {world, []}
    else
      labor = Person.effective_labor(person)
      hours_worked = World.get_parcel(world, parcel_id).acres * 1.0 / max(labor, 0.1)
      energy_cost = GovSim.Systems.Nutrition.energy_cost(hours_worked, labor)

      world =
        World.update_person(world, person_id, fn p ->
          %{p | current_task: nil, energy: max(0.0, p.energy - energy_cost)}
        end)

      parcel = World.get_parcel(world, parcel_id)

      # Fire the actual crop_plant event to set parcel state and schedule growth
      crop_plant_event = Event.new(time + 1, :crop_plant, parcel_id, %{crop: crop})

      log_entry = %{
        time: time,
        type: :plant_complete,
        system: :labor,
        message: "#{person.name} finishes planting #{parcel.name} with #{crop}."
      }

      {World.log_event(world, log_entry), [crop_plant_event]}
    end
  end

  # -- Harvesting --

  def handle(%Event{type: :harvest_begin, time: time, entity_id: person_id, payload: payload}, world) do
    world = %{world | sim_time: time}
    parcel_id = payload.parcel_id
    person = World.get_person(world, person_id)
    parcel = World.get_parcel(world, parcel_id)

    if person == nil or parcel == nil do
      {world, []}
    else
      labor = Person.effective_labor(person)
      duration = AgriSystem.harvest_duration(parcel.acres, labor)

      world =
        world
        |> World.update_person(person_id, fn p ->
          %{p | current_task: %{type: :harvesting, parcel_id: parcel_id, started_at: time}}
        end)
        |> World.update_parcel(parcel_id, fn p -> %{p | state: :harvesting} end)

      complete_event =
        Event.new(time + duration, :harvest_complete, person_id, %{parcel_id: parcel_id})

      log_entry = %{
        time: time,
        type: :harvest_begin,
        system: :labor,
        message:
          "#{person.name} begins harvesting #{parcel.name} (#{parcel.acres} acres, est. #{div(duration, 60)} hours)."
      }

      {World.log_event(world, log_entry), [complete_event]}
    end
  end

  def handle(%Event{type: :harvest_complete, time: time, entity_id: person_id, payload: payload}, world) do
    world = %{world | sim_time: time}
    parcel_id = payload.parcel_id
    person = World.get_person(world, person_id)
    parcel = World.get_parcel(world, parcel_id)

    if person == nil or parcel == nil do
      {world, []}
    else
      yield = AgriSystem.calculate_yield(parcel.acres, parcel.crop)
      labor = Person.effective_labor(person)
      hours_worked = parcel.acres * 2.0 / max(labor, 0.1)
      energy_cost = GovSim.Systems.Nutrition.energy_cost(hours_worked, labor)

      world =
        world
        |> World.update_person(person_id, fn p ->
          %{p | current_task: nil, energy: max(0.0, p.energy - energy_cost)}
        end)
        |> World.update_parcel(parcel_id, fn p ->
          %{p | state: :fallow, crop: nil, growth_progress: 0.0, planted_at: nil}
        end)
        |> World.update_household(person.household_id, fn hh ->
          %{hh | inventory: GovSim.Entities.Inventory.add(hh.inventory, :wheat_bushels, yield)}
        end)

      log_entry = %{
        time: time,
        type: :harvest_complete,
        system: :labor,
        message:
          "#{person.name} finishes harvesting #{parcel.name}! Yielded #{Float.round(yield, 1)} bushels of wheat."
      }

      {World.log_event(world, log_entry), []}
    end
  end

  # Generic work_begin/work_complete (delegate to harvest for now)
  def handle(%Event{type: :work_begin} = event, world) do
    handle(%{event | type: :harvest_begin}, world)
  end

  def handle(%Event{type: :work_complete} = event, world) do
    handle(%{event | type: :harvest_complete}, world)
  end
end

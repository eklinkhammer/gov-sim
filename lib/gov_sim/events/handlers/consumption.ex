defmodule GovSim.Events.Handlers.Consumption do
  @moduledoc """
  Handlers for hunger_tick, person_try_eat, daily_dawn.
  """

  @behaviour GovSim.Events.Handler

  alias GovSim.Events.Event
  alias GovSim.World.World
  alias GovSim.Systems.Nutrition
  alias GovSim.Simulation.Clock

  @impl true
  def handle(%Event{type: :daily_dawn, time: time}, world) do
    world = %{world | sim_time: time}

    # Schedule hunger ticks for all persons (every 4 hours: 6:00, 10:00, 14:00, 18:00, 22:00)
    day = Clock.day_number(time)
    persons = Map.values(world.persons)

    # One hunger_tick per time slot (processes all persons together)
    hunger_events =
      for hour <- [6, 10, 14, 18, 22] do
        tick_time = day * Clock.minutes_per_day() + hour * 60
        if tick_time > time, do: Event.new(tick_time, :hunger_tick)
      end
      |> Enum.reject(&is_nil/1)

    # Schedule field assessment for AI household heads at 7:00
    # Skip the player household head — the player issues commands manually
    heads = Enum.filter(persons, fn p ->
      hh = World.get_household(world, p.household_id)
      hh && hh.head_id == p.id && hh.id != world.player_household_id
    end)

    assess_events =
      for head <- heads do
        Event.new(day * Clock.minutes_per_day() + 7 * 60, :person_assess_fields, head.id)
      end

    # Schedule next dawn
    next_dawn = Clock.dawn(day + 1)
    next_dawn_event = Event.new(next_dawn, :daily_dawn)

    # Rest recovery: restore some energy overnight (living only)
    world =
      Enum.reduce(persons, world, fn person, w ->
        if person.alive do
          World.update_person(w, person.id, fn p ->
            %{p | energy: min(1.0, p.energy + Nutrition.energy_recovery_rate())}
          end)
        else
          w
        end
      end)

    log_entry = %{time: time, type: :daily_dawn, message: "Dawn breaks. #{Clock.format(time)}."}
    world = World.log_event(world, log_entry)

    {world, hunger_events ++ assess_events ++ [next_dawn_event]}
  end

  def handle(%Event{type: :hunger_tick, time: time}, world) do
    world = %{world | sim_time: time}
    persons = Map.values(world.persons)

    living = Enum.filter(persons, & &1.alive)

    {world, eat_events} =
      Enum.reduce(living, {world, []}, fn person, {w, evts} ->
        increase = Nutrition.hunger_increase(person.age)
        new_hunger = min(1.0, person.hunger + increase)

        # Starvation: high hunger drains energy and forces task abandonment
        {energy_penalty, starvation_log} =
          cond do
            new_hunger >= 0.9 ->
              {Nutrition.starvation_energy_drain(),
               %{time: time, type: :starvation, system: :consumption,
                 message: "#{person.name} is starving! Losing strength."}}
            new_hunger >= 0.7 ->
              {Nutrition.starvation_energy_drain() * 0.5,
               %{time: time, type: :starvation, system: :consumption,
                 message: "#{person.name} is weak from hunger."}}
            true ->
              {0.0, nil}
          end

        new_energy = max(0.0, person.energy - energy_penalty)

        # Death: starving with no energy left
        dies = new_hunger >= 1.0 and new_energy <= 0.0

        # If energy hits zero, drop current task
        drop_task = new_energy <= 0.0 and person.current_task != nil

        w = World.update_person(w, person.id, fn p ->
          cond do
            dies ->
              %{p | hunger: 1.0, energy: 0.0, alive: false, current_task: nil}
            drop_task ->
              %{p | hunger: new_hunger, energy: new_energy, current_task: nil}
            true ->
              %{p | hunger: new_hunger, energy: new_energy}
          end
        end)

        w = if starvation_log && !dies, do: World.log_event(w, starvation_log), else: w

        w =
          if dies do
            World.log_event(w, %{
              time: time, type: :death, system: :consumption,
              message: "#{person.name} has died of starvation."
            })
          else
            if drop_task do
              World.log_event(w, %{
                time: time, type: :collapse, system: :consumption,
                message: "#{person.name} collapses from exhaustion and cannot work!"
              })
            else
              w
            end
          end

        new_evts =
          if !dies and new_hunger >= Nutrition.eat_threshold() do
            [Event.new(time + 5, :person_try_eat, person.id) | evts]
          else
            evts
          end

        {w, new_evts}
      end)

    {world, eat_events}
  end

  def handle(%Event{type: :person_try_eat, time: time, entity_id: person_id}, world) do
    world = %{world | sim_time: time}

    case World.get_person(world, person_id) do
      nil ->
        {world, []}

      %{alive: false} ->
        {world, []}

      person ->
        household = World.get_household(world, person.household_id)

        if household do
          meal_size = Nutrition.meal_size(person.age)

          case GovSim.Entities.Inventory.remove(household.inventory, :wheat_bushels, meal_size) do
            {:ok, new_inv} ->
              world =
                world
                |> World.update_household(household.id, fn hh -> %{hh | inventory: new_inv} end)
                |> World.update_person(person_id, fn p ->
                  %{p | hunger: max(0.0, p.hunger - 0.3)}
                end)

              log_entry = %{
                time: time,
                type: :person_try_eat,
                system: :consumption,
                message: "#{person.name} eats (#{Float.round(meal_size, 3)} bushels)."
              }

              {World.log_event(world, log_entry), []}

            {:insufficient, _available} ->
              log_entry = %{
                time: time,
                type: :person_try_eat,
                system: :consumption,
                message: "#{person.name} is hungry but the granary is empty!"
              }

              {World.log_event(world, log_entry), []}
          end
        else
          {world, []}
        end
    end
  end
end

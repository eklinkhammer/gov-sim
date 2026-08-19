defmodule GovSim.Events.Handlers.Agriculture do
  @moduledoc """
  Handlers for crop_plant, crop_growth_check, crop_ready.
  """

  @behaviour GovSim.Events.Handler

  alias GovSim.Events.Event
  alias GovSim.World.World
  alias GovSim.Systems.Agriculture, as: AgriSystem
  alias GovSim.Simulation.Clock

  @impl true
  def handle(%Event{type: :crop_plant, time: time, entity_id: parcel_id, payload: payload}, world) do
    world = %{world | sim_time: time}
    crop = Map.get(payload, :crop, :wheat)

    world =
      World.update_parcel(world, parcel_id, fn parcel ->
        %{parcel | crop: crop, state: :planted, growth_progress: 0.0, planted_at: time}
      end)

    # Schedule first growth check
    check_time = time + AgriSystem.growth_check_interval()
    growth_event = Event.new(check_time, :crop_growth_check, parcel_id)

    parcel = World.get_parcel(world, parcel_id)

    log_entry = %{
      time: time,
      type: :crop_plant,
      system: :agriculture,
      message: "#{parcel.name}: #{crop} planted on #{parcel.acres} acres."
    }

    {World.log_event(world, log_entry), [growth_event]}
  end

  def handle(%Event{type: :crop_growth_check, time: time, entity_id: parcel_id}, world) do
    world = %{world | sim_time: time}

    case World.get_parcel(world, parcel_id) do
      nil ->
        {world, []}

      %{state: state} when state not in [:planted, :growing] ->
        {world, []}

      parcel ->
        progress = AgriSystem.growth_progress(parcel.planted_at, time)

        world =
          World.update_parcel(world, parcel_id, fn p ->
            %{p | growth_progress: progress, state: :growing}
          end)

        if progress >= 1.0 do
          # Crop is ready!
          ready_event = Event.new(time + 1, :crop_ready, parcel_id)

          log_entry = %{
            time: time,
            type: :crop_growth_check,
            system: :agriculture,
            message: "#{parcel.name}: wheat is fully grown and ready for harvest!"
          }

          {World.log_event(world, log_entry), [ready_event]}
        else
          # Schedule next check
          next_check = time + AgriSystem.growth_check_interval()
          check_event = Event.new(next_check, :crop_growth_check, parcel_id)
          pct = round(progress * 100)

          log_entry = %{
            time: time,
            type: :crop_growth_check,
            system: :agriculture,
            message: "#{parcel.name}: wheat at #{pct}% growth. #{Clock.format(time)}."
          }

          {World.log_event(world, log_entry), [check_event]}
        end
    end
  end

  def handle(%Event{type: :crop_ready, time: time, entity_id: parcel_id}, world) do
    world = %{world | sim_time: time}

    world =
      World.update_parcel(world, parcel_id, fn parcel ->
        %{parcel | state: :ready, growth_progress: 1.0}
      end)

    parcel = World.get_parcel(world, parcel_id)

    log_entry = %{
      time: time,
      type: :crop_ready,
      system: :agriculture,
      message: "#{parcel.name}: crop is ready for harvest!"
    }

    {World.log_event(world, log_entry), []}
  end
end

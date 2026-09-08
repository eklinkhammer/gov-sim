defmodule GovSim.Events.Registry do
  @moduledoc """
  Maps event type atoms to handler modules.
  """

  alias GovSim.Events.Handlers.{Agriculture, Consumption, Labor, Player, Social}

  @handlers %{
    # Consumption
    daily_dawn: Consumption,
    hunger_tick: Consumption,
    person_try_eat: Consumption,
    # Agriculture
    crop_plant: Agriculture,
    crop_growth_check: Agriculture,
    crop_ready: Agriculture,
    # Labor
    person_assess_fields: Labor,
    plant_begin: Labor,
    plant_complete: Labor,
    harvest_begin: Labor,
    harvest_complete: Labor,
    work_begin: Labor,
    work_complete: Labor,
    # Social
    request_work: Social,
    evaluate_request: Social,
    request_accepted: Social,
    request_refused: Social,
    # Player commands
    player_command_plant: Player,
    player_command_harvest: Player,
    player_command_request_labor: Player
  }

  def get_handler(event_type) do
    case Map.get(@handlers, event_type) do
      nil -> {:error, :unknown_event_type}
      handler -> {:ok, handler}
    end
  end

  def known_type?(event_type), do: Map.has_key?(@handlers, event_type)
end

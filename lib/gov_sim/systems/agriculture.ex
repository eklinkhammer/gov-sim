defmodule GovSim.Systems.Agriculture do
  @moduledoc """
  Yield calculations, growth durations, harvest labor requirements.
  """

  alias GovSim.Simulation.Clock

  # Wheat grows for ~120 days (March 1 to ~July 1)
  @wheat_growth_days 120
  @growth_check_interval_days 10

  # Yield: ~8 bushels per acre for medieval wheat
  @wheat_yield_per_acre 8.0

  # Harvest: ~2 hours per acre per unit of labor capacity
  @harvest_hours_per_acre 2.0

  # Planting: ~1 hour per acre per unit of labor capacity
  @plant_hours_per_acre 1.0

  # Planting season: first 30 days
  @planting_season_days 30

  def wheat_growth_days, do: @wheat_growth_days
  def growth_check_interval_days, do: @growth_check_interval_days
  def wheat_yield_per_acre, do: @wheat_yield_per_acre

  @doc "Growth check interval in sim minutes"
  def growth_check_interval do
    @growth_check_interval_days * Clock.minutes_per_day()
  end

  @doc "Total growth time in sim minutes"
  def wheat_growth_time do
    @wheat_growth_days * Clock.minutes_per_day()
  end

  @doc "Calculate yield for a parcel"
  def calculate_yield(acres, crop \\ :wheat) do
    case crop do
      :wheat -> acres * @wheat_yield_per_acre
      _ -> acres * @wheat_yield_per_acre
    end
  end

  @doc "Calculate harvest duration in minutes for given acres and labor capacity"
  def harvest_duration(acres, labor_capacity) do
    hours = @harvest_hours_per_acre * acres / max(labor_capacity, 0.1)
    round(hours * 60)
  end

  @doc "Calculate planting duration in minutes for given acres and labor capacity"
  def plant_duration(acres, labor_capacity) do
    hours = @plant_hours_per_acre * acres / max(labor_capacity, 0.1)
    round(hours * 60)
  end

  @doc "Is it planting season?"
  def planting_season?(sim_time) do
    Clock.day_number(sim_time) < @planting_season_days
  end

  @doc "Calculate growth progress (0.0 to 1.0) based on elapsed time"
  def growth_progress(planted_at, current_time) do
    elapsed = current_time - planted_at
    min(elapsed / wheat_growth_time(), 1.0)
  end
end

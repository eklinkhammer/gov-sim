defmodule GovSim.Systems.Nutrition do
  @moduledoc """
  Caloric rates, bushels per meal, hunger mechanics.
  """

  # A person eats ~0.03 bushels per meal (roughly 2 meals/day = 0.06 bushels/day)
  # At 8 bushels starting, family of 3 eats ~0.18 bushels/day = ~44 days of food
  @bushels_per_meal 0.03

  # Hunger increases per tick (hunger_tick fires every 4 hours = 6x/day)
  # Full hunger (1.0) reached in ~2 days without eating
  @hunger_per_tick 0.08

  # Energy recovery per rest period (overnight) — partial, not full restore
  @energy_recovery_rate 0.15

  # Hunger threshold at which person will try to eat
  @eat_threshold 0.4

  # Energy drained per hunger tick when starving (hunger >= 0.9)
  @starvation_energy_drain 0.1

  def bushels_per_meal, do: @bushels_per_meal
  def hunger_per_tick, do: @hunger_per_tick
  def energy_recovery_rate, do: @energy_recovery_rate
  def eat_threshold, do: @eat_threshold
  def starvation_energy_drain, do: @starvation_energy_drain

  @doc "Calculate hunger increase for a tick, factoring in age"
  def hunger_increase(age) when age < 12, do: @hunger_per_tick * 0.7
  def hunger_increase(_age), do: @hunger_per_tick

  @doc "Bushels needed based on age"
  def meal_size(age) when age < 12, do: @bushels_per_meal * 0.7
  def meal_size(_age), do: @bushels_per_meal

  @doc "Energy cost of labor based on hours worked and labor capacity"
  def energy_cost(hours, _labor_capacity) do
    # ~0.1 per hour worked — 5 hours of planting costs 0.5 energy
    hours * 0.1
  end
end

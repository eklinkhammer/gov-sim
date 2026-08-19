defmodule GovSim.Simulation.Clock do
  @moduledoc """
  SimTime: minutes from March 1 (day 0).
  240-day growing season = 345,600 minutes.
  """

  @minutes_per_hour 60
  @hours_per_day 24
  @minutes_per_day @minutes_per_hour * @hours_per_day

  # March 1 is day 0
  @month_days [
    {3, 31},
    {4, 30},
    {5, 31},
    {6, 30},
    {7, 31},
    {8, 31},
    {9, 30},
    {10, 31}
  ]

  @month_names %{
    3 => "March",
    4 => "April",
    5 => "May",
    6 => "June",
    7 => "July",
    8 => "August",
    9 => "September",
    10 => "October"
  }

  def minutes_per_day, do: @minutes_per_day

  @doc "Convert sim_time (minutes) to {month, day, hour, minute}"
  def to_date(sim_time) when is_integer(sim_time) and sim_time >= 0 do
    total_days = div(sim_time, @minutes_per_day)
    remaining_minutes = rem(sim_time, @minutes_per_day)
    hour = div(remaining_minutes, @minutes_per_hour)
    minute = rem(remaining_minutes, @minutes_per_hour)

    {month, day} = day_to_month_day(total_days)
    {month, day, hour, minute}
  end

  @doc "Format sim_time as a human-readable string"
  def format(sim_time) do
    {month, day, hour, minute} = to_date(sim_time)
    month_name = Map.get(@month_names, month, "Month #{month}")
    "#{month_name} #{day}, #{pad(hour)}:#{pad(minute)}"
  end

  @doc "Format just the date portion"
  def format_date(sim_time) do
    {month, day, _hour, _minute} = to_date(sim_time)
    month_name = Map.get(@month_names, month, "Month #{month}")
    "#{month_name} #{day}"
  end

  @doc "Get the sim_time for dawn (6:00) of a given day number"
  def dawn(day_number) when is_integer(day_number) and day_number >= 0 do
    day_number * @minutes_per_day + 6 * @minutes_per_hour
  end

  @doc "Get the day number from sim_time"
  def day_number(sim_time), do: div(sim_time, @minutes_per_day)

  @doc "Convert {month, day, hour, minute} to sim_time"
  def from_date(month, day, hour \\ 0, minute \\ 0) do
    days = month_day_to_days(month, day)
    days * @minutes_per_day + hour * @minutes_per_hour + minute
  end

  defp day_to_month_day(total_days) do
    Enum.reduce_while(@month_days, total_days, fn {month, days_in_month}, remaining ->
      if remaining < days_in_month do
        {:halt, {month, remaining + 1}}
      else
        {:cont, remaining - days_in_month}
      end
    end)
    |> case do
      {_month, _day} = result -> result
      remaining -> {10, remaining + 1}
    end
  end

  defp month_day_to_days(month, day) do
    Enum.reduce_while(@month_days, 0, fn {m, days_in_month}, acc ->
      if m == month do
        {:halt, acc + day - 1}
      else
        {:cont, acc + days_in_month}
      end
    end)
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end

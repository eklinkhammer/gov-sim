defmodule GovSim.World.Succession do
  @moduledoc """
  Heir succession logic for the player avatar.
  Priority: oldest male child → oldest female child → spouse → oldest surviving member → game over.
  """

  alias GovSim.World.World
  alias GovSim.Entities.Person

  @doc """
  Find the heir for a deceased person within their household.
  Returns `{:heir, person_id}` or `:game_over`.
  """
  def find_heir(%World{} = world, deceased_id) do
    deceased = World.get_person(world, deceased_id)
    household = World.get_household(world, deceased.household_id)

    survivors =
      household.member_ids
      |> Enum.map(&World.get_person(world, &1))
      |> Enum.filter(&(&1 && Person.alive?(&1) && &1.id != deceased_id))

    # Children: persons whose relationship map has deceased_id => :parent
    children = Enum.filter(survivors, fn p ->
      Map.get(p.relationships, deceased_id) == :parent
    end)

    male_children =
      children
      |> Enum.filter(&(&1.sex == :male))
      |> Enum.sort_by(& &1.age, :desc)

    female_children =
      children
      |> Enum.filter(&(&1.sex == :female))
      |> Enum.sort_by(& &1.age, :desc)

    # Spouse: person whose relationship map has deceased_id => :spouse
    spouse = Enum.find(survivors, fn p ->
      Map.get(p.relationships, deceased_id) == :spouse
    end)

    # Oldest surviving member
    oldest = Enum.max_by(survivors, & &1.age, fn -> nil end)

    cond do
      male_children != [] -> {:heir, hd(male_children).id}
      female_children != [] -> {:heir, hd(female_children).id}
      spouse != nil -> {:heir, spouse.id}
      oldest != nil -> {:heir, oldest.id}
      true -> :game_over
    end
  end

  @doc """
  Apply succession result to the world. Updates player_avatar_id, household head_id,
  and logs the event. Sets game_over if no heir found.
  """
  def apply_succession(%World{} = world, deceased_id, {:heir, heir_id}, time) do
    deceased = World.get_person(world, deceased_id)
    heir = World.get_person(world, heir_id)

    world
    |> Map.put(:player_avatar_id, heir_id)
    |> World.update_household(deceased.household_id, fn hh ->
      %{hh | head_id: heir_id}
    end)
    |> World.log_event(%{
      time: time,
      type: :succession,
      system: :succession,
      message: "#{heir.name} succeeds #{deceased.name} as head of household."
    })
  end

  def apply_succession(%World{} = world, deceased_id, :game_over, time) do
    deceased = World.get_person(world, deceased_id)

    world
    |> Map.put(:game_over, true)
    |> World.log_event(%{
      time: time,
      type: :game_over,
      system: :succession,
      message: "#{deceased.name}'s household has no surviving members. Game over."
    })
  end
end

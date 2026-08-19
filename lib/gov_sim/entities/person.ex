defmodule GovSim.Entities.Person do
  @moduledoc """
  Person struct: hunger, energy, personality, relationships, current task.
  """

  defstruct [
    :id,
    :name,
    :age,
    :household_id,
    hunger: 0.0,
    energy: 1.0,
    labor_capacity: 1.0,
    alive: true,
    current_task: nil,
    personality: %{},
    relationships: %{}
  ]

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          age: integer(),
          household_id: atom(),
          hunger: float(),
          energy: float(),
          labor_capacity: float(),
          alive: boolean(),
          current_task: map() | nil,
          personality: map(),
          relationships: map()
        }

  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc "Labor capacity based on age"
  def effective_labor(%__MODULE__{labor_capacity: cap, energy: energy}) do
    cap * energy
  end

  def hungry?(%__MODULE__{hunger: hunger}), do: hunger >= 0.6
  def starving?(%__MODULE__{hunger: hunger}), do: hunger >= 0.9
  def busy?(%__MODULE__{current_task: task}), do: task != nil
  def alive?(%__MODULE__{alive: alive}), do: alive
  def dead?(%__MODULE__{alive: alive}), do: not alive
end

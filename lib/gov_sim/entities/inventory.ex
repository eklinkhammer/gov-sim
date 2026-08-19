defmodule GovSim.Entities.Inventory do
  @moduledoc """
  Resource inventory: maps resource atoms to amounts.
  """

  defstruct resources: %{}

  @type t :: %__MODULE__{
          resources: %{atom() => number()}
        }

  def new(initial \\ %{}) do
    %__MODULE__{resources: initial}
  end

  def get(%__MODULE__{resources: resources}, resource) do
    Map.get(resources, resource, 0)
  end

  def add(%__MODULE__{resources: resources} = inv, resource, amount) when amount >= 0 do
    current = Map.get(resources, resource, 0)
    %{inv | resources: Map.put(resources, resource, current + amount)}
  end

  @doc "Remove amount of resource. Returns {:ok, inventory} or {:insufficient, available}"
  def remove(%__MODULE__{resources: resources} = inv, resource, amount) when amount >= 0 do
    current = Map.get(resources, resource, 0)

    if current >= amount do
      {:ok, %{inv | resources: Map.put(resources, resource, current - amount)}}
    else
      {:insufficient, current}
    end
  end

  @doc "Remove amount, clamping to 0 if insufficient. Returns {actual_removed, inventory}"
  def remove_up_to(%__MODULE__{resources: resources} = inv, resource, amount) when amount >= 0 do
    current = Map.get(resources, resource, 0)
    actual = min(current, amount)
    {actual, %{inv | resources: Map.put(resources, resource, current - actual)}}
  end

  def has?(%__MODULE__{} = inv, resource, amount) do
    get(inv, resource) >= amount
  end

  def to_list(%__MODULE__{resources: resources}) do
    Enum.filter(resources, fn {_k, v} -> v > 0 end)
  end
end

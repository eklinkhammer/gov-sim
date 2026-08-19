defmodule GovSim.Entities.Parcel do
  @moduledoc """
  Farm parcel struct: crop state, acres, growth progress.
  """

  defstruct [
    :id,
    :household_id,
    :name,
    acres: 5.0,
    crop: nil,
    state: :fallow,
    growth_progress: 0.0,
    planted_at: nil
  ]

  @type state :: :fallow | :planting | :planted | :growing | :ready | :harvesting
  @type t :: %__MODULE__{
          id: atom(),
          household_id: atom(),
          name: String.t(),
          acres: float(),
          crop: atom() | nil,
          state: state(),
          growth_progress: float(),
          planted_at: integer() | nil
        }

  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  def ready?(%__MODULE__{state: :ready}), do: true
  def ready?(_), do: false

  def needs_harvest?(%__MODULE__{state: state}), do: state == :ready
end

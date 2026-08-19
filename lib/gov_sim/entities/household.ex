defmodule GovSim.Entities.Household do
  @moduledoc """
  Household struct: head, members, inventory, parcels, pending requests.
  """

  alias GovSim.Entities.Inventory

  defstruct [
    :id,
    :name,
    :head_id,
    member_ids: [],
    parcel_ids: [],
    inventory: %Inventory{},
    pending_requests: []
  ]

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          head_id: atom(),
          member_ids: [atom()],
          parcel_ids: [atom()],
          inventory: Inventory.t(),
          pending_requests: list()
        }

  def new(attrs) do
    struct!(__MODULE__, attrs)
  end
end

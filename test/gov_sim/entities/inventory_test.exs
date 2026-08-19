defmodule GovSim.Entities.InventoryTest do
  use ExUnit.Case, async: true

  alias GovSim.Entities.Inventory

  test "new creates inventory with initial resources" do
    inv = Inventory.new(%{wheat_bushels: 8.0})
    assert Inventory.get(inv, :wheat_bushels) == 8.0
  end

  test "get returns 0 for missing resources" do
    inv = Inventory.new()
    assert Inventory.get(inv, :wheat_bushels) == 0
  end

  test "add increases resource amount" do
    inv = Inventory.new(%{wheat_bushels: 5.0})
    inv = Inventory.add(inv, :wheat_bushels, 3.0)
    assert Inventory.get(inv, :wheat_bushels) == 8.0
  end

  test "remove succeeds when enough resources" do
    inv = Inventory.new(%{wheat_bushels: 8.0})
    {:ok, inv} = Inventory.remove(inv, :wheat_bushels, 3.0)
    assert Inventory.get(inv, :wheat_bushels) == 5.0
  end

  test "remove fails when insufficient" do
    inv = Inventory.new(%{wheat_bushels: 2.0})
    assert {:insufficient, 2.0} = Inventory.remove(inv, :wheat_bushels, 5.0)
  end

  test "remove_up_to clamps to available" do
    inv = Inventory.new(%{wheat_bushels: 2.0})
    {actual, inv} = Inventory.remove_up_to(inv, :wheat_bushels, 5.0)
    assert actual == 2.0
    assert Inventory.get(inv, :wheat_bushels) == 0.0
  end

  test "has? checks resource availability" do
    inv = Inventory.new(%{wheat_bushels: 8.0})
    assert Inventory.has?(inv, :wheat_bushels, 5.0)
    refute Inventory.has?(inv, :wheat_bushels, 10.0)
  end
end

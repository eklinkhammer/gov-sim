defmodule GovSim.Systems.DecisionTest do
  use ExUnit.Case, async: true

  alias GovSim.Systems.Decision

  test "obedient child accepts parent/head request" do
    {decision, score, _factors} =
      Decision.evaluate(%{
        requester_is_head: true,
        relationship: :parent,
        energy: 0.8,
        obedience: 0.85
      })

    assert decision == :accept
    assert score > 0
  end

  test "tired, disobedient person may refuse" do
    {decision, score, _factors} =
      Decision.evaluate(%{
        requester_is_head: false,
        relationship: :stranger,
        energy: 0.1,
        obedience: 0.1
      })

    assert decision == :refuse
    assert score < 0
  end

  test "factors are returned with names, values, and weights" do
    {_decision, _score, factors} =
      Decision.evaluate(%{
        requester_is_head: true,
        relationship: :parent,
        energy: 0.8,
        obedience: 0.7
      })

    assert length(factors) == 4

    Enum.each(factors, fn {name, value, weight} ->
      assert is_atom(name)
      assert is_number(value)
      assert is_number(weight)
    end)
  end

  test "Thomas-like profile (obedience 0.7) accepts father's request" do
    {decision, _score, _factors} =
      Decision.evaluate(%{
        requester_is_head: true,
        relationship: :parent,
        energy: 0.7,
        obedience: 0.7
      })

    assert decision == :accept
  end

  test "Agnes-like profile (obedience 0.85) strongly accepts" do
    {decision, score, _factors} =
      Decision.evaluate(%{
        requester_is_head: true,
        relationship: :parent,
        energy: 0.8,
        obedience: 0.85
      })

    assert decision == :accept
    assert score > 0.3
  end
end

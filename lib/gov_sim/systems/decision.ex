defmodule GovSim.Systems.Decision do
  @moduledoc """
  Universal decision engine. Every person uses the same evaluate/1 function.
  Behavior differences emerge from attributes (age, personality, relationships).

  Factors: authority, relationship, energy, personality.
  Weighted average; positive = comply, negative = refuse.
  """

  @doc """
  Evaluate a request. Returns {decision, score, factors} where
  decision is :accept or :refuse, score is the weighted average,
  and factors is a list of {name, value, weight} tuples.
  """
  def evaluate(params) do
    factors = [
      authority_factor(params),
      relationship_factor(params),
      energy_factor(params),
      personality_factor(params)
    ]

    total_weight = Enum.reduce(factors, 0, fn {_, _, w}, acc -> acc + w end)

    score =
      if total_weight > 0 do
        weighted_sum = Enum.reduce(factors, 0, fn {_, v, w}, acc -> acc + v * w end)
        weighted_sum / total_weight
      else
        0.0
      end

    decision = if score >= 0, do: :accept, else: :refuse
    {decision, Float.round(score, 3), factors}
  end

  # Authority: household head asking child = strong positive
  defp authority_factor(%{requester_is_head: true}) do
    {:authority, 0.8, 3.0}
  end

  defp authority_factor(_), do: {:authority, 0.0, 1.0}

  # Relationship: parent-child = positive
  defp relationship_factor(%{relationship: rel}) do
    value =
      case rel do
        :parent -> 0.6
        :sibling -> 0.3
        :stranger -> -0.2
        _ -> 0.0
      end

    {:relationship, value, 2.0}
  end

  defp relationship_factor(_), do: {:relationship, 0.0, 1.0}

  # Energy: low energy = reluctance
  defp energy_factor(%{energy: energy}) do
    value = energy - 0.5
    {:energy, Float.round(value, 2), 1.5}
  end

  defp energy_factor(_), do: {:energy, 0.0, 1.0}

  # Personality: obedience trait
  defp personality_factor(%{obedience: obedience}) do
    value = obedience - 0.5
    {:personality, Float.round(value, 2), 2.0}
  end

  defp personality_factor(_), do: {:personality, 0.0, 1.0}
end

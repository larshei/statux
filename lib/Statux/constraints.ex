defmodule Statux.Constraints do

  alias Statux.Models.TrackingData


  # Termination conditions
  def constraints_fulfilled?(nil = _constraints, _option, _tracking), do: true
  def constraints_fulfilled?(constraints, _option, _tracking) when constraints == %{}, do: true

  # Previous status OK?
  # while available here, this constraint is checked earlier to skip all the evaluations if not necessary.
  def constraints_fulfilled?(%{previous_status: status_constraints} = constraints, option, %TrackingData{} = tracking) do
    case Statux.ValueRules.valid?(tracking.consecutive_message_count, status_constraints) do
      true -> constraints_fulfilled?(constraints |> Map.delete(:count), option, tracking)
      false -> false
    end
  end

  # count okay?
  def constraints_fulfilled?(%{count: %{n_of_m: [n, _m]}} = constraints, option, %TrackingData{} = tracking) do
    case tracking.valid_history_true_count >= n do
      true -> constraints_fulfilled?(constraints |> Map.delete(:count), option, tracking)
      false -> false
    end
  end
  def constraints_fulfilled?(%{count: count_constraints} = constraints, option, %TrackingData{n_of_m_constraint: nil} = tracking) do
    case Statux.ValueRules.valid?(tracking.consecutive_message_count, count_constraints) do
      true -> constraints_fulfilled?(constraints |> Map.delete(:count), option, tracking)
      false -> false
    end
  end

  # duration okay?
  def constraints_fulfilled?(%{duration: duration_constraints} = constraints, option, %TrackingData{} = tracking) do
    case Statux.ValueRules.valid?(tracking.occurred_at, duration_constraints) do
      true -> constraints_fulfilled?(constraints |> Map.delete(:duration), option, tracking)
      false -> false
    end
  end
end

defmodule Statux.Constraints do

  alias Statux.Models.EntityStatus
  alias Statux.Models.TrackingData

  def filter_valid_transition_options(%EntityStatus{} = entity_state, status_name, status_options, options) when is_list(options) do
    options
    |> Enum.map(fn option ->
      entity_state
      |> check_transition_constraints(status_name, status_options, option)
    end)
    |> Enum.filter(fn {transition?, _from, _to} -> transition? end)
  end

  def check_transition_constraints(%EntityStatus{} = entity_state, status_name, status_options, option) when is_atom(option) do
    current_status = entity_state.current_status[status_name][:current]

    case status_options[option][:constraints] do
      nil ->
        {true, current_status, option}
      constraints ->
        transition? =
          constraints_fulfilled?(
            constraints,
            option,
            entity_state.tracking[status_name][option]
          )

        {transition?, current_status, option}
    end
  end

  # Termination conditions
  def constraints_fulfilled?(nil = _constraints, _option, _tracking), do: true
  def constraints_fulfilled?(constraints, _option, _tracking) when constraints == %{}, do: true

  # Previous status OK?
  def constraints_fulfilled?(%{previous_status: status_constraints} = constraints, option, %TrackingData{} = tracking) do
    case Statux.ValueRules.valid?(tracking.consecutive_message_count, status_constraints) do
      true -> constraints_fulfilled?(constraints |> Map.delete(:previous_status), option, tracking)
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

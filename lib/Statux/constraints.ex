defmodule Statux.Constraints do

  alias Statux.Models.EntityStatus
  alias Statux.Models.TrackingData
  alias Statux.ValueRules

  def filter_valid_transition_options(%EntityStatus{} = entity_state, status_name, status_options, options) when is_list(options) do
    options
    |> Enum.map(fn option ->
      entity_state
      |> check_transition_constraints(status_name, status_options, option)
    end)
    |> Enum.filter(fn {transition?, _from, _to} -> transition? end)
  end

  def check_transition_constraints(%EntityStatus{} = entity_state, status_name, status_options, option) when is_atom(option) do
    latest_status = entity_state.current_status[status_name][:current]

    previous_status_ok? = case status_options[option][:constraints][:previous_status] do
      nil -> true
      previous_status_constraint ->
        ValueRules.valid?(latest_status, previous_status_constraint)
    end

    # we evaluate the :previous_status constraint first to save some computation.
    transition? =
      previous_status_ok?
      and
      constraints_fulfilled?(
        status_options[option][:constraints] |> Map.delete(:previous_status),
        option,
        entity_state.tracking[status_name][option]
      )

    # for example {true, :low, :ok}, {false, :critical, :ok}, {true, :ok, :ok}
    {transition?, latest_status, option}
  end

  # Termination conditions
  def constraints_fulfilled?(nil = _constraints, _option, _tracking), do: true
  def constraints_fulfilled?(constraints, _option, _tracking) when constraints == %{}, do: true

  # Previous status OK?
  # while available here, this constraint is checked earlier to skip all the evaluations if not necessary.
  # def constraints_fulfilled?(%{previous_status: status_constraints} = constraints, option, %TrackingData{} = tracking) do
  #   case Statux.ValueRules.valid?(tracking.consecutive_message_count, status_constraints) do
  #     true -> constraints_fulfilled?(Map.pop(constraints, :previous_status) |> elem(1), option, tracking)
  #     false -> false
  #   end
  # end

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

defmodule Statux.Constraints do

  alias Statux.Models.EntityStatus
  alias Statux.Models.TrackingData
  @doc """
  Takes three arguments:
  1. A status that we might want to transition to
  2. A state describing the current status
  3. Constraints.

  Returns a tuple like `{transition?, state}`
  ## Examples

  This example shows a constraint of getting at least 3 messages of type :low,
  over at least 10 minutes.
  The current state of the system is, that already 2 inputs for :low have arrived, and
  the oldest one arrived an hour ago. Therefore, if another :low message
  arrives, we have a total of >= 3 messages that are at least 10 minutes old.

  If another message came in, e.g. :ok instead of :low, the pending status will
  be updated to hold an :ok message and the tra

      iex> {:ok, occurance_at, _} = "2021-01-01T00:00:00Z" |> DateTime.from_iso8601
      ...> current_state = %{
      ...>   pending: {:low, occurance_at, 2},
      ...>   history: []
      ...> }
      ...> rules = %{
      ...>   battery_alarm: %{
      ...>     low: %{
      ...>       constraints: %{count: %{min: 3}, duration: %{min: "PT10M" |> Timex.Duration.parse!()}},
      ...>     }}}
      ...> filter_constraints_fulfilled([:low], current_state, rules.battery_alarm[:low][:constraints])
      {true, %{history: [{~U[2021-01-01 00:00:00Z], :low}], pending: nil}}
  """
  # This case matches whenever the status we would like to transition to is
  # already the latest status.


  def filter_constraints_fulfilled(incoming_status, %{history: [{_at, last_status_in_history} | _]} = previous_state, _constraints)
  when incoming_status == last_status_in_history
  do
    transition? = false

    {transition?, previous_state}
  end

  # This case matches if the incoming status is the same as the pending status
  def filter_constraints_fulfilled(incoming_status, %{pending: {current_status, occurred_at, occurred_count}, history: history}, constraints)
  when current_status == incoming_status
  do
    occurred_time_ago =
      DateTime.utc_now()
      |> Timex.Comparable.diff(occurred_at, :seconds)
      |> Timex.Duration.from_seconds

    incremented_occurred_count = occurred_count + 1

    transition? =
      constraints_fulfilled?({occurred_time_ago, incremented_occurred_count}, constraints)

    case transition? do
      true ->
        {transition?, %{pending: nil, history: [{occurred_at, incoming_status} | history]}}
      false ->
        {transition?, %{pending: {incoming_status, occurred_at, incremented_occurred_count}, history: history}}
    end
  end

  # This case matches if the incoming status is different from the current
  # status. in that case, the pending status does not matter. We only validate if
  # we can directly transition into the next status or now.
  def filter_constraints_fulfilled(incoming_status, %{history: history}, constraints) do
    now = DateTime.utc_now()

    duration_from_now = %Timex.Duration{megaseconds: 0, seconds: 0, microseconds: 0}
    occurred_count = 1

    transition? =
      constraints_fulfilled?({duration_from_now, occurred_count}, constraints)

    case transition? do
      true ->
        {transition?, %{pending: nil, history: [{now, incoming_status} | history]}}
      false ->
        {transition?, %{pending: {incoming_status, now, occurred_count}, history: history}}
    end
  end

  defp constraints_fulfilled?(_, %{} = constraints) when constraints == %{}, do: true

  defp constraints_fulfilled?({_occurred_time_ago, occurred_count} = pending, %{count: count_constraints} = constraints) do
    case Statux.ValueRules.valid?(occurred_count, count_constraints) do
      true -> constraints_fulfilled?(pending, constraints |> Map.delete(:count))
      false -> false
    end
  end

  defp constraints_fulfilled?({occurred_time_ago, _occurred_count} = pending, %{duration: duration_constraints} = constraints) do
    case Statux.ValueRules.valid?(occurred_time_ago, duration_constraints) do
      true -> constraints_fulfilled?(pending, constraints |> Map.delete(:duration))
      false -> false
    end
  end

  # if we got here, all existing rules were checked. This case covers remaining
  # constraints that have not been removed from the constraints map.
  defp constraints_fulfilled?(_pending, _constraints), do: true

end

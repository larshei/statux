defmodule Statex.ValueRules do
  @moduledoc """
  Provides the rules handling for the status system.

  Expectes to get the actual value and the value constraints of states.
  Returns if the state is valid or not.
  """

  @doc """
  Takes a set of rules and runs through them. Returns the first status that the
  value rules match for.

  ## Example

      iex> rules = %{
      ...>  battery_alarm: %{
      ...>     critical: %{
      ...>       constraints: %{count: %{min: 3}, duration: %{min: "PT10M" |> Timex.Duration.parse!()}},
      ...>       value: %{lt: 11.8}
      ...>     },
      ...>     low: %{
      ...>       constraints: %{count: %{min: 3}, duration: %{min: "PT10M" |> Timex.Duration.parse!()}},
      ...>       value: %{max: 12.0, min: 11.8}
      ...>     },
      ...>     ok: %{constraints: %{count: %{min: 3}}, value: %{gt: 12.1}}
      ...>   }
      ...> }
      ...> find_valid_state(12.6, rules.battery_alarm)
      :ok
      iex> find_valid_state(11.8, rules.battery_alarm)
      :low
      iex> find_valid_state(11.3, rules.battery_alarm)
      :critical
  """
  def find_valid_state(value, rules_as_map) do
    rules_as_map
    |> Enum.reduce(nil, fn {status_name, %{value: rule}}, acc ->
      case acc do
        nil ->
          case valid?(value, rule) do
            false -> nil
            true -> status_name
          end
        status ->
          status
      end
    end)
  end

  @doc """
  Takes a set of rules and runs through them. Returns the first status that the
  value rules match for. May be used to check just a subset of validators.
  Keys that do not exist in the rule set are ignored.

  Similar to :find_valid_state, but executes the checks in the given order.
  If your rules are done properly, the order should not matter.
  However, this can be used to find out conflicts, i.e. when you have rules
  that overlap and the first rule that matches is taken.

  ## Example

  Both :min and :max include the set value, so the following rule set has a
  conflict for the value 11.8:

      iex> rules = %{
      ...>  overlapping: %{
      ...>     low: %{
      ...>       value: %{max: 11.8}
      ...>     },
      ...>     high: %{
      ...>       value: %{min: 11.8}
      ...>     },
      ...>   }
      ...> }
      ...> find_valid_state(11.8, rules.overlapping, [:low, :high])
      :low
      iex> find_valid_state(11.8, rules.overlapping, [:high, :low])
      :high
      iex> find_valid_state(11.8, rules.overlapping, [:not_valid, :low])
      :low
  """
  def find_valid_state(value, rules_as_map, order_of_status_checks) do
    valid_statuses_in_order =
      order_of_status_checks
      |> Enum.filter(fn status_name -> rules_as_map[status_name][:value] != nil end)

    valid_statuses_in_order
    |> Enum.reduce(nil, fn status_name, acc ->
      case acc do
        nil ->
          case valid?(value, rules_as_map[status_name][:value]) do
            false -> nil
            true -> status_name
          end
        status ->
          status
      end
    end)
  end

  @doc """
  Pass in a value and a rule set to check wether the value confirms to the
  rules or not.

  Valid rules are:

  | numeric | `:max`, `:min`, `:lt`, `:gt`
  | any value | `:is`, `:not`, `:is`, `:not`


  ## Example

      iex> valid?(12, %{max: 12})
      true
      iex> valid?(12, %{min: 12})
      true
      iex> valid?(12, %{lt: 12})
      false
      iex> valid?(12, %{gt: 12})
      false
      iex> valid?(11.9, %{lt: 12})
      true
      iex> valid?(12.1, %{gt: 12})
      true
      iex> valid?(11.5, %{min: 11.7, max: 12})
      false
      iex> valid?(11.7, %{is: 11.7})
      true
      iex> valid?(11.5, %{is: 11.7})
      false
      iex> valid?(11.5, %{not: 11.7})
      true
      iex> valid?(11.7, %{not: 11.7})
      false
      iex> valid?(11.5, %{is: [11.5, 11.7]})
      true
      iex> valid?(11.6, %{is: [11.5, 11.7]})
      false
      iex> valid?(11.5, %{not: [11.5, 11.7]})
      false
      iex> valid?(11.6, %{not: [11.5, 11.7]})
      true
      iex> valid?(11.6, %{max: 12, min: 10, not: [11.6]})
      false
      iex> valid?(11, %{max: 12, min: 10, not: [11.6]})
      true
      iex> valid?(9, %{max: 12, min: 10, not: [11.6]})
      false
      iex> valid?(:no, %{max: 12, min: 10, not: [:no]})
      false
      iex> valid?(:yes, %{max: 12, min: 10, not: [:no]})
      true
      iex> valid?(DateTime.utc_now() |> Timex.shift(minutes: -10), %{min: "PT8M" |> Timex.Duration.parse!()})
      true
      iex> valid?(DateTime.utc_now() |> Timex.shift(minutes: -5), %{min: "PT8M" |> Timex.Duration.parse!()})
      false
      iex> valid?(DateTime.utc_now() |> Timex.shift(minutes: -5), %{max: "PT8M" |> Timex.Duration.parse!()})
      true
      iex> valid?(DateTime.utc_now() |> Timex.shift(minutes: -10), %{max: "PT8M" |> Timex.Duration.parse!()})
      false
      iex> valid?(DateTime.utc_now() |> Timex.shift(minutes: -10), %{is: "PT10M" |> Timex.Duration.parse!()})
      true
      iex> valid?(DateTime.utc_now() |> Timex.shift(minutes: -10), %{not: "PT10M" |> Timex.Duration.parse!()})
      false
  """
  def valid?(_value, nil), do: true

  def valid?(value, rule) do
    check_valid(value, rule)
  end

  # rules for max, min, gt, lt, is, not.
  # Reduces the constraints until either
  # 1. A constraint is not fulfilled or
  # 2. No more constraints are left to be checked
  # When no constraint is left to be checked, all constraints have been
  # fulfilled.

  ## No rules left
  defp check_valid(_value, rule) when rule == %{}, do: true
  ## NUMERIC COMPARISONS
  defp check_valid(value, %{max: max} = rule) when is_number(value) and value <= max, do: check_valid(value, rule |> Map.delete(:max))
  defp check_valid(value, %{max: _max} = _rule) when is_number(value), do: false
  defp check_valid(value, %{min: min} = rule) when is_number(value) and value >= min, do: check_valid(value, rule |> Map.delete(:min))
  defp check_valid(value, %{min: _min} = _rule) when is_number(value), do: false
  defp check_valid(value, %{lt: less} = rule) when is_number(value) and value < less, do: check_valid(value, rule |> Map.delete(:lt))
  defp check_valid(value, %{lt: _less} = _rule) when is_number(value), do: false
  defp check_valid(value, %{gt: more} = rule) when is_number(value) and value > more, do: check_valid(value, rule |> Map.delete(:gt))
  defp check_valid(value, %{gt: _more} = _rule) when is_number(value), do: false
  ## CONVERT AN INCOMING DATETIME TO A DURATION
  defp check_valid(%DateTime{} = datetime, rules), do: check_valid(duration_to_now(datetime), rules)
  ## DURATION COMPARISONS
  defp check_valid(%Timex.Duration{} = time_ago, %{max: %Timex.Duration{} = duration} = rule) when time_ago <= duration, do: check_valid(time_ago, rule |> Map.delete(:max))
  defp check_valid(%Timex.Duration{}, %{max: %Timex.Duration{}}), do: false
  defp check_valid(%Timex.Duration{} = time_ago, %{min: %Timex.Duration{} = duration} = rule) when time_ago >= duration, do: check_valid(time_ago, rule |> Map.delete(:min))
  defp check_valid(%Timex.Duration{}, %{min: %Timex.Duration{}}), do: false
  defp check_valid(%Timex.Duration{} = time_ago, %{lt: %Timex.Duration{} = duration} = rule) when time_ago < duration, do: check_valid(time_ago, rule |> Map.delete(:lt))
  defp check_valid(%Timex.Duration{}, %{lt: %Timex.Duration{}}), do: false
  defp check_valid(%Timex.Duration{} = time_ago, %{gt: %Timex.Duration{} = duration} = rule) when time_ago > duration, do: check_valid(time_ago, rule |> Map.delete(:gt))
  defp check_valid(%Timex.Duration{}, %{gt: %Timex.Duration{}}), do: false

  ## EQUALITY COMPARISONS
  defp check_valid(value, %{is: list} = rule) when is_list(list) do
    case value in list do
      true -> check_valid(value, rule |> Map.delete(:is))
      false -> false
    end
  end
  defp check_valid(value, %{is: is} = rule) when value == is, do: check_valid(value, rule |> Map.delete(:is))
  defp check_valid(_value, %{is: _is} = _rules), do: false

  ## INEQUALITY COMPARISONS
  defp check_valid(value, %{not: list} = rule) when is_list(list) do
    case value not in list do
      true -> check_valid(value, rule |> Map.delete(:not))
      false -> false
    end
  end
  defp check_valid(value, %{not: is_not} = rule) when value != is_not, do: check_valid(value, rule |> Map.delete(:not))
  defp check_valid(_value, %{not: _not} = _rules), do: false

  # if we got here we checked all relevant values -> true.
  # We might end up here when we check if "string" is smaller than 12.
  defp check_valid(_value, %{} = _rules), do: true

  defp duration_to_now(%DateTime{} = datetime), do: Timex.diff(DateTime.utc_now(), datetime, :seconds) |> Timex.Duration.from_seconds()
end

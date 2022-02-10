defmodule Statux.ValueRules do
  @moduledoc """
  Provides the rules handling for the status system.

  Expects to get the actual value and the value constraints of states.
  Returns if the state is valid or not.
  """


  def should_be_ignored?(_value, %{ignore: nil}), do: false
  def should_be_ignored?(value, %{ignore: rules}), do: check_value_constraints(value, rules)
  def should_be_ignored?(_value, _rules_without_ignore_section), do: false

  @doc """
  Takes a set of options and runs through them.

  Returns the first option that the value rules match for.
  When the options are `nil`, what might happen when a set of options is
  selected that does not exist, an empty list is returned.

  ## Example

      iex> battery_alarm_options = %{
      ...>   critical: %{
      ...>     constraints: %{count: %{min: 3}, duration: %{min: "PT10M" |> Timex.Duration.parse!()}},
      ...>     value: %{lt: 11.8}
      ...>   },
      ...>   low: %{
      ...>     constraints: %{count: %{min: 3}, duration: %{min: "PT10M" |> Timex.Duration.parse!()}},
      ...>     value: %{max: 12.0, min: 11.8}
      ...>   },
      ...>   ok: %{constraints: %{count: %{min: 3}}, value: %{gt: 12.1}}
      ...> }
      ...> find_possible_valid_status(12.6, battery_alarm_options)
      [:ok]
      iex> find_possible_valid_status(11.8, battery_alarm_options)
      [:low]
      iex> find_possible_valid_status(11.3, battery_alarm_options)
      [:critical]
      iex> find_possible_valid_status(11.3, nil)
      []
  """
  def find_possible_valid_status(_value, nil), do: []
  def find_possible_valid_status(value, rules_as_map) do
    find_possible_valid_status(value, rules_as_map, Map.keys(rules_as_map))
  end

  @doc """
  Takes a set of rules and runs through them. Returns the first status that the
  value rules match for. May be used to check just a subset of validators.
  Keys that do not exist in the rule set are ignored.

  Similar to :find_possible_valid_status, but executes the checks in the given order.
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
      ...> find_possible_valid_status(11.8, rules.overlapping, [:low, :high])
      [:high, :low]
      iex> find_possible_valid_status(11.8, rules.overlapping, [:high, :low])
      [:low, :high]
      iex> find_possible_valid_status(11.8, rules.overlapping, [:not_valid, :low])
      [:low]
  """
  def find_possible_valid_status(value, rules_as_map, order_of_status_checks) do
    valid_statuses_in_order =
      order_of_status_checks
      |> Enum.filter(fn status_name -> rules_as_map[status_name] != nil end)

    valid_statuses_in_order
    |> Enum.reduce([], fn status_name, acc ->
      case check_value_constraints(value, rules_as_map[status_name]) do
        true -> [status_name | acc]
        false -> acc
      end
    end)
  end

  defp check_value_constraints(_value, %{value: nil}), do: true
  defp check_value_constraints(value, %{value: value_constraints}), do: valid?(value, value_constraints)
  defp check_value_constraints(_value, _), do: true

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
  def valid?(value, rule) when is_number(value), do: check_number(value, rule)
  def valid?(%Timex.Duration{} = value, rule), do: check_number(value, rule)
  def valid?(%DateTime{} = value, rule), do: check_number(duration_to_now(value), rule)
  def valid?(value, rule), do: check_equality(value, rule)

  defp duration_to_now(%DateTime{} = datetime), do: Timex.diff(DateTime.utc_now(), datetime, :seconds) |> Timex.Duration.from_seconds()

  # rules for max, min, gt, lt, is, not.
  # Reduces the constraints until either
  # 1. A constraint is not fulfilled or
  # 2. No more constraints are left to be checked
  # When no constraint is left to be checked, all constraints have been
  # fulfilled.

  ## No rules left
  ## NUMERIC COMPARISONS
  defp check_number(_value, rule) when rule == %{}, do: true
  defp check_number(value, %{max: max} = rule) when max != :passed and value <= max, do: check_number(value, %{rule | max: :passed})
  defp check_number(_value, %{max: max} = _rule) when max != :passed, do: false
  defp check_number(value, %{min: min} = rule) when min != :passed and value >= min, do: check_number(value, %{rule | min: :passed})
  defp check_number(_value, %{min: min} = _rule) when min != :passed, do: false
  defp check_number(value, %{lt: less} = rule) when less != :passed and value < less, do: check_number(value, %{rule | lt: :passed})
  defp check_number(_value, %{lt: less} = _rule) when less != :passed, do: false
  defp check_number(value, %{gt: more} = rule) when more != :passed and value > more, do: check_number(value, %{rule | gt: :passed})
  defp check_number(_value, %{gt: more} = _rule) when more != :passed, do: false
  defp check_number(_value, rule) when rule == %{}, do: true
  defp check_number(value, rule), do: check_equality(value, rule)

  ## EQUALITY COMPARISONS
  defp check_equality(value, %{is: list} = rule) when is_list(list) do
    case value in list do
      true -> check_equality(value, %{rule | is: :passed})
      false -> false
    end
  end
  defp check_equality(value, %{is: is} = rule) when value == is, do: check_equality(value, %{rule | is: :passed})
  defp check_equality(_value, %{is: is} = _rules) when is != :passed, do: false

  ## INEQUALITY COMPARISONS
  defp check_equality(value, %{not: list} = rule) when is_list(list) do
    case value not in list do
      true -> check_equality(value, %{rule | not: :passed})
      false -> false
    end
  end
  defp check_equality(value, %{not: is_not} = rule) when is_not != :passed and value != is_not, do: check_equality(value, %{rule | not: :passed})
  defp check_equality(_value, %{not: is_not} = _rules) when is_not != :passed, do: false

  # if we got here we checked all relevant values -> true.
  # We might end up here when we check if "string" is smaller than 12.
  defp check_equality(_value, %{} = _rules), do: true

end

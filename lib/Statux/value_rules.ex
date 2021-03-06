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

  You may specify specific :return_as values to customize what is returned for valid states other
  than their status name:

      iex> rules = %{
      ...>   return: %{
      ...>     one: %{
      ...>       value: %{max: 11.8}, return_as: 1,
      ...>     },
      ...>     two: %{
      ...>       value: %{min: 11.8}, return_as: "2",
      ...>     },
      ...>   },
      ...> }
      ...> find_possible_valid_status(11.8, rules.overlapping, [:one, :two])
      ["2", 1]
  """
  def find_possible_valid_status(value, rules_as_map, order_of_status_checks) do
    valid_statuses_in_order =
      order_of_status_checks
      |> Enum.filter(fn status_name -> rules_as_map[status_name] != nil end)

    valid_statuses_in_order
    |> Enum.reduce([], fn status_name, acc ->
      case check_value_constraints(value, rules_as_map[status_name]) do
        true ->
          name = rules_as_map[status_name][:return_as] || status_name
          [name | acc]
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

  | numeric   | `:max`, `:min`, `:lt`, `:gt`
  | string    | `:contains`, `:starts_with`, `:ends_with`, `:does_not_contain` # TODOL Implement
  | any value | `:is`, `:not`


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
      iex> valid?("test", %{not: "test"})
      false
      iex> valid?("test", %{match: ~r(test)})
      true
      iex> valid?("test", %{contains: "test"})
      true
      iex> valid?("test", %{is: "test"})
      true
      iex> valid?("test", %{is: ["test", "world"]})
      true
      iex> valid?("test", %{not: ["test", "world"]})
      false
      iex> valid?("ab_test_cd", %{match: [~r(\\d{4})]})
      false
      iex> valid?("ab_1234_cd", %{match: [~r(\\d{4})]})
      true
      iex> valid?("ab_1234_cd", %{match: [~r(\\d{8}), ~r(_\\d{4}_)]})
      true
  """
  def valid?(_value, nil), do: true
  def valid?(value, rule) when is_number(value), do: check_number(value, rule)
  def valid?(%Timex.Duration{} = value, rule), do: check_number(value, rule)
  def valid?(%DateTime{} = value, rule), do: check_number(duration_to_now(value), rule)
  def valid?(value, rule) when is_bitstring(value), do: check_string(value, rule)
  def valid?(value, rule), do: check_equality(value, rule)

  defp duration_to_now(%DateTime{} = datetime), do: Timex.diff(DateTime.utc_now(), datetime, :seconds) |> Timex.Duration.from_seconds()

  # rules for max, min, gt, lt, is, not, ...
  # Reduces the constraints until either
  # 1. A constraint is not fulfilled or
  # 2. No more constraints are left to be checked
  # When no constraint is left to be checked, all constraints have been
  # fulfilled.

  defp check_string(_value, rule) when rule == %{}, do: true
  defp check_string(value, %{contains: expr} = rule), do:
    if String.contains?(value, expr), do: check_string(value, rule |> Map.delete(:contains)), else: false
  defp check_string(value, %{match: exprs} = rule) when is_list(exprs), do: # List of expressions, if ANY is true -> all good
    if Enum.reduce(exprs, false, fn expr, acc -> acc or Regex.match?(expr, value) end), do: check_string(value, rule |> Map.delete(:match)), else: false
  defp check_string(value, %{match: expr} = rule), do:
    if Regex.match?(expr, value), do: check_string(value, rule |> Map.delete(:match)), else: false
  defp check_string(value, rule), do: check_equality(value, rule)

  defp check_number(_value, rule) when rule == %{}, do: true
  defp check_number(value, %{max: max} = rule) when value <= max, do: check_number(value, rule |> Map.delete(:max))
  defp check_number(_value, %{max: _max} = _rule), do: false
  defp check_number(value, %{min: min} = rule) when value >= min, do: check_number(value, rule |> Map.delete(:min))
  defp check_number(_value, %{min: _min} = _rule), do: false
  defp check_number(value, %{lt: less} = rule) when value < less, do: check_number(value, rule |> Map.delete(:lt))
  defp check_number(_value, %{lt: _less} = _rule), do: false
  defp check_number(value, %{gt: more} = rule) when value > more, do: check_number(value, rule |> Map.delete(:gt))
  defp check_number(_value, %{gt: _more} = _rule), do: false
  defp check_number(_value, rule) when rule == %{}, do: true
  defp check_number(value, rule), do: check_equality(value, rule)

  ## EQUALITY COMPARISONS
  defp check_equality(value, %{is: list} = rule) when is_list(list) do
    case value in list do
      true -> check_equality(value, rule |> Map.delete(:is))
      false -> false
    end
  end
  defp check_equality(value, %{is: is} = rule) when value == is, do: check_equality(value, rule |> Map.delete(:is))
  defp check_equality(_value, %{is: _is} = _rules), do: false

  ## INEQUALITY COMPARISONS
  defp check_equality(value, %{not: list} = rule) when is_list(list) do
    case value not in list do
      true -> check_equality(value, rule |> Map.delete(:not))
      false -> false
    end
  end
  defp check_equality(value, %{not: is_not} = rule) when value != is_not, do: check_equality(value, rule |> Map.delete(:not))
  defp check_equality(_value, %{not: _is_not} = _rules), do: false

  # if we got here we checked all relevant values -> true.
  # We might end up here when we check if "string" is smaller than 12.
  defp check_equality(_value, %{} = _rules), do: true

end

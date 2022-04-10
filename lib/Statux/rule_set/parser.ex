defmodule Statux.RuleSet.Parser do
  @allowed_keys_top_levels %{
    0 => :any,
    1 => ["ignore", "status"],
    2 => :any,
    3 => ["constraints", "value", "return_as"],
  }
  @allowed_keys_deeper_levels ["duration", "count", "min", "max", "is", "not", "lt", "gt", "n_of_m", "previous_status", "contains", "match"]
  @allowed_constraints %{
    "previous_status" => ["is", "not"],
    "count" => ["min", "n_of_m", "is", "not", "n_of_m"],
    "duration" => ["min", "max", "lt", "gt"],
    "value" => ["min", "max", "lt", "gt", "is", "not"],
  }

  def parse!(json) when is_bitstring(json) do
    json
    |> Jason.decode!
    |> Enum.into(%{}, fn k_v_tuple ->
      parse_rule_set!(k_v_tuple, [])
    end)
    |> ensure_status_constraints_refer_to_existing_status!
  end

  def serialize!(%{} = map) do
    map
    |> stringify_durations
    |> Jason.encode!
  end

  # Private Functions
  defp stringify_path(path) do
    path
    |> Enum.reverse
    |> Enum.join(".")
  end

  # specific check to not mix conditions like "min" in "count"
  defp parse_rule_set!({"count" = key, constraints}, parent_keys) when is_map(constraints) do
    keys = constraints |> Map.keys()
    case Enum.member?(keys, "n_of_m") and length(keys) > 1 do
      true -> raise "The condition \"n_of_m\" in cannot be mixed with other count conditions. Remove either \"n_of_m\" or all of #{inspect keys -- ["n_of_m"]} in #{[key | parent_keys] |> stringify_path}"
      false ->
        {
          key |> check_key!(parent_keys) |> String.to_atom(),
          constraints |> Enum.into(%{}, fn k_v_tuple -> parse_rule_set!(k_v_tuple, [key | parent_keys]) end)
        }
    end
  end

  defp parse_rule_set!({key, constraints}, parent_keys) when is_map(constraints) do
    {
      key |> check_key!(parent_keys) |> String.to_atom(),
      constraints |> Enum.into(%{}, fn k_v_tuple -> parse_rule_set!(k_v_tuple, [key | parent_keys]) end)
    }
  end

  defp parse_rule_set!({key, value}, parent_keys), do:
    {
      key |> check_key!(parent_keys) |> String.to_atom(),
      maybe_parse_value(value, [key | parent_keys])
    }

  defp maybe_parse_value(values, ["match", "value" | _] = path) when is_list(values) do
    Enum.map(values, fn value -> maybe_parse_value(value, path) end)
  end

  defp maybe_parse_value(value, ["match", "value" | _] = path) when is_bitstring(value) do
    case Regex.compile(value) do
      {:ok, regex} -> regex
      {:error, error} -> raise "cannot compile regex '#{value}' in #{path |> stringify_path}: #{inspect error}"
    end
  end

  defp maybe_parse_value(value, ["duration", "constraints" | _] = path) when is_bitstring(value) do
    try do
      Timex.Duration.parse!(value)
    rescue
      _ -> raise "Invalid iso8601 duration '#{value}' in #{path |> stringify_path}"
    end
  end
  defp maybe_parse_value(value, [_, "duration", "constraints" | _]) when is_integer(value) do
      Timex.Duration.from_seconds(value)
  end
  defp maybe_parse_value(value, [_, "duration", "constraints" | _]) when is_bitstring(value) do
    Timex.Duration.parse!(value)
  end
  defp maybe_parse_value(value, [_, "previous_status", "constraints" | _]) when is_bitstring(value) do
    String.to_atom(value)
  end

  # Parse rules for counts
  defp maybe_parse_value(value, [_, "count", "constraints" | _]) when is_integer(value) do
    value
  end
  defp maybe_parse_value(value, ["n_of_m", "count", "constraints" | _]) when is_list(value) do
    value
  end
  defp maybe_parse_value(value, ["n_of_m", "count", "constraints" | _] = path) do
    raise "Count must be a list, got #{inspect value} in #{path |> stringify_path}"
  end
  defp maybe_parse_value(value, [_, "count", "constraints" | _] = path) do
    raise "Count must be an integer, got #{inspect value} in #{path |> stringify_path}"
  end

  defp maybe_parse_value(_value, [_, "previous_status"| _] = path) do
    raise "#{path |> stringify_path}: 'previous_status' must be inside 'constraints'"
  end
  defp maybe_parse_value(_value, [_, "duration"| _] = path) do
    raise "#{path |> stringify_path}: 'duration' must be inside 'constraints'"
  end
  defp maybe_parse_value(_value, ["count"| _] = path) do
    raise "#{path |> stringify_path}: 'count' must be inside 'constraints'"
  end
  defp maybe_parse_value(value, _parent_keys), do: value

  defp check_key!(key, ["value", "ignore" | _] = path) do
    if key not in @allowed_constraints["value"], do: raise "Unsupported constraint: '#{key}' in #{path |> stringify_path}. Allowed values are #{inspect @allowed_constraints["value"]}"

    key
  end
  defp check_key!(key, path) do
    nested_deepness = path |> length()

    case @allowed_keys_top_levels[nested_deepness] do
      :any -> :ok
      nil ->
        if key not in @allowed_keys_deeper_levels, do: raise "Unsupported constraint: '#{key}' in #{path |> stringify_path}. Allowed values are #{inspect @allowed_keys_deeper_levels}"
      allowed_keys ->
        if key not in allowed_keys, do: raise "Unsupported constraint: '#{key}' in #{path |> stringify_path}. Allowed values are #{inspect allowed_keys}"
    end

    key
  end

  defp ensure_status_constraints_refer_to_existing_status!(rule_set) do
    rule_set
    |> Map.values()
    |> Enum.map(fn status_rules ->
      allowed_status = status_rules |> Map.keys()

      status_rules
      |> Map.values()
      |> Enum.reduce(true, fn rule_for_status, ok? ->
        case ok? do
          false -> false
          true -> previous_status_in_allowed_status(rule_for_status, allowed_status)
        end
      end)
    end)

    rule_set
  end

  defp previous_status_in_allowed_status(rule_for_status, allowed_status) do
    rule_for_status[:constraints][:previous_status]
    |> case do
      nil -> true
      previous_status_rules ->
        previous_status_rules
        |> Enum.reduce(true, fn {_key, status}, ok? ->
          case ok? do
            true ->
              if status not in allowed_status do
                allowed_status_stringified = allowed_status |> Enum.map(fn status -> "#{status}" end)
                raise "Status \"#{status}\" not allowed. Allowed values are #{inspect allowed_status_stringified}"
              end
            not_ok -> not_ok
          end
        end)
    end
  end

  defp stringify_durations({key, %Timex.Duration{} = duration}), do:
    {key, duration |> Timex.Duration.to_string()}
  defp stringify_durations({key, map}) when is_map(map), do:
    {key, map |> Enum.into(%{}, fn k_v_tuple -> stringify_durations(k_v_tuple) end)}
  defp stringify_durations({key, value}), do:
    {key, value}
  defp stringify_durations(%{} = map), do:
    map |> Enum.into(%{}, fn k_v_tuple -> stringify_durations(k_v_tuple) end)

end

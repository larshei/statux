defmodule Statex.RuleSet do
  @moduledoc """
  Handles reading configurations from and storing configurations to disk
  """

  @allowed_keys ["value", "constraints", "duration", "count", "min", "max", "is", "not", "lt", "gt"]


  def load_json!(path) do
    path
    |> File.read!()
    |> from_json!
  end


  def from_json!(json) do
    json
    |> Jason.decode!()
    |> parse_rule_set()
  end


  defp parse_rule_set({key, constraints}, nested_level) when is_map(constraints), do:
    {
      key |> check_key!(nested_level) |> String.to_atom(),
      constraints |> Enum.into(%{}, fn k_v_tuple -> parse_rule_set(k_v_tuple, nested_level + 1) end)
    }

  defp parse_rule_set({key, value}, nested_level), do:
    {
      key |> check_key!(nested_level) |> String.to_atom(),
      maybe_parse_duration(value)
    }

  defp parse_rule_set(%{} = map), do:
    map |> Enum.into(%{}, fn k_v_tuple -> parse_rule_set(k_v_tuple, 0) end)


  defp maybe_parse_duration(value) when is_bitstring(value) do
    try do
      Timex.Duration.parse!(value)
    rescue
      _ -> value
    end
  end
  defp maybe_parse_duration(value), do: value


  defp check_key!(key, n) when n >= 2 do
    if key not in @allowed_keys, do: raise "Unsupported key: '#{key}'. Allowed values are #{inspect @allowed_keys}"
    key
  end
  defp check_key!(key, _), do: key

  def to_json(rule_set) do
    rule_set
    |> stringify_durations()
    |> Jason.encode!()
  end

  def stringify_durations({key, %Timex.Duration{} = duration}), do:
    {key, duration |> Timex.Duration.to_string()}
  def stringify_durations({key, map}) when is_map(map), do:
    {key, map |> Enum.into(%{}, fn k_v_tuple -> stringify_durations(k_v_tuple) end)}
  def stringify_durations({key, value}), do:
    {key, value}
  def stringify_durations(%{} = map), do:
    map |> Enum.into(%{}, fn k_v_tuple -> stringify_durations(k_v_tuple) end)

end

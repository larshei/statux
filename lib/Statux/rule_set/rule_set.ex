defmodule Statux.RuleSet do
  @moduledoc """
  Handles reading configurations from and storing configurations to disk
  """
  alias Statux.RuleSet.Parser

  def load_json!(path) do
    path
    |> File.read!
    |> from_json!
  end

  def from_json!(json) do
    json
    |> Parser.parse!
  end

  def to_json!(rule_set) do
    rule_set
    |> Parser.serialize!()
  end

  def save(%{} = rule_set) do
    rule_set
    |> to_json!()
    |> save()
  end

  def save(json_rule_set) when is_bitstring(json_rule_set) do
    Application.get_env(:statux, :rule_set_file)
    |> File.write!(json_rule_set)
  end

  def save(_rule_set, _rule_set_name) do
    raise "Multiple Rule Sets are not yet supported"
  end

  def reload_for(server_name) do
    Statux.Tracker.reload_rule_set(server_name)
  end
end

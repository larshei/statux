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

  def to_json(rule_set) do
    rule_set
    |> Parser.serialize!()
  end

end

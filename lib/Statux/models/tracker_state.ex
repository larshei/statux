defmodule Statux.Models.TrackerState do
  @moduledoc """
  The internal state of the Tracker.
  If you are not planning on significantly changing the library, this is
  probably not of much interest to you.
  """
  use StructAccess
  use TypedStruct

  typedstruct do
    field :rules, map(), default: %{}
    field :states, map(), default: %{}
    field :pubsub, atom(), default: nil
    field :statistics, map(), default: %{}
  end

  def new(default_rules, pubsub \\ nil, states \\ %{}) do
    %__MODULE__{
      rules: %{default: default_rules},
      states: states,
      pubsub: pubsub,
    }
  end

  def set_pubsub(state, pubsub) do
    state |> Map.put(:pubsub, pubsub)
  end

  def set_rule_set(state, rule_set) do
    state |> put_in([:rules, :default], rule_set)
  end

  def set_rule_set(state, rule_set, id) do
    state |> put_in([:rules, id], rule_set)
  end

  def get_rule_set(state, id \\ :default)
  def get_rule_set(state, :default), do: state.rules[:default]
  def get_rule_set(state, id), do: state.rules[id] || state.rules[:default]
end

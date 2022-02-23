defmodule Statux.Models.TrackerState do
  @moduledoc """
  The internal state of the Tracker.
  If you are not planning on significantly changing the library, this is
  probably not of much interest to you.
  """
  use StructAccess
  use TypedStruct

  typedstruct do
    field :name, String.t() | atom(), required: true
    field :persistence, map(), default: %{enabled: false, folder: nil}
    field :pubsub, atom(), default: %{module: nil, topic: nil}
    field :rule_set_file, String.t(), required: true
    field :rules, map(), default: %{}
    field :states, map(), default: %{}
    field :statistics, map(), default: %{}
  end

  def new(default_rules, pubsub \\ %{module: nil, topic: nil}, states \\ %{}) do
    %__MODULE__{
      rules: %{default: default_rules},
      states: states,
      pubsub: pubsub,
    }
  end

  def set_pubsub(state, %{module: _, topic: _} = pubsub) do
    %{ state | pubsub: pubsub}
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

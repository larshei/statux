defmodule Statux.Transitions do
  @moduledoc """
  Handles evaluation and execution of a Transition from one to another or the same status.
  """

  alias Statux.Models.EntityStatus
  alias Statux.Models.Status

  require Logger

  @doc """
  Pass in an entity state, a list of options and the name of the status

      iex> maybe_transition(entity_state, :battery_voltage, [:low])
      updated_entity_state

  to check constraints for the given status_name and options and, if the constraints are
  fulfilled, alter the entity_state to the new status.

  As a side effect, this function may

  1. broadcast PubSub messages, if PubSub is configured, and/or
  2. trigger the callback functions provided in the rule set for :enter, :stay, :exit (to be
     implemented)

  You may use these side effects to react to updates in your application.
  """
  def transition(%EntityStatus{} = entity_state, _status_name, [] = _no_valid_options) do
    entity_state
  end

  # One valid option -> Awesome
  def transition(%EntityStatus{} = entity_state, status_name, [{transition?, from, to}]) do
    same_as_before? = from == to

    cond do
      transition? and same_as_before? ->
        IO.puts "Staying in #{to}"
        entity_state
        # TODO PubSub broadcast -> kept old status
      transition? and not same_as_before? ->
        IO.puts "Exiting #{from}"
        IO.puts "Entering #{to}"
        # TODO PubSub broadcast -> exit old status
        modify_current_state_in_entity(entity_state, status_name, to)
        # TODO PubSub broadcast -> enter new status

      true ->
        IO.puts "No valid option."

        entity_state # Constraints not fulfilled, nothing to do.
    end
  end

  # Multiple valid options. How do we choose?! Log error -> pick first.
  def transition(%EntityStatus{} = entity_state, status_name, [{_true, from, to} = option | _other_options] = options) do
    Logger.error("Statux conflict: Tried to transition '#{status_name}' from '#{from}' to multiple options #{inspect options |> Enum.map(fn {_, _, option} -> option end)} simultaneously. Defaulting to first option '#{to}'.")
    transition(%EntityStatus{} = entity_state, status_name, [option])
  end

  defp modify_current_state_in_entity(entity_state, status_name, option) do
    entity_state
    |> update_in([:current_status, Access.key(status_name, %{})], fn status ->
      Status.set_status(status, option)
    end)
  end
end

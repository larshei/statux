defmodule Statux.Transitions do
  alias Statux.Constraints
  alias Statux.Models.EntityStatus
  alias Statux.Models.Status
  @doc """
  Receives a list of options that passed the tests and an already updated entity state.

  Checks wether the constraints for the given options are
  """
  def maybe_transition(%EntityStatus{} = entity_state, _status_name, _status_options, []) do
    entity_state
  end

  def maybe_transition(%EntityStatus{} = entity_state, status_name, status_options, options) when is_list(options) do
    options
    |> Enum.reduce(entity_state, fn option, updated_entity_status ->
      updated_entity_status
      |> maybe_transition(status_name, status_options, option)
    end)
  end

  def maybe_transition(%EntityStatus{} = entity_state, status_name, status_options, option) do
    entity_state.tracking[status_name][option]

    previous_status_ok? = case status_options[option][:constraints][:previous_status] do
      nil -> true
      previous_status ->
        entity_state.current_status[status_name][:current] in previous_status
    end

    # we evaluate the :previous_status constraint first to save some computation.
    transition? =
      previous_status_ok?
      and
      Constraints.constraints_fulfilled?(
        status_options[option][:constraints] |> Map.delete(:previous_state),
        option,
        entity_state.tracking[status_name][option]
      )

    same_as_before? = option == entity_state.current_status[status_name][:current]

    cond do
      transition? and same_as_before? ->
        entity_state
        # TODO PubSub broadcast -> kept old status
      transition? and not same_as_before? ->
        # TODO PubSub broadcast -> exit old status
        modify_current_state_in_entity(entity_state, status_name, option)
        # TODO PubSub broadcast -> enter new status
      true -> entity_state # Constraints not fulfilled, nothing to do.
    end
  end

  defp modify_current_state_in_entity(entity_state, status_name, option) do
    entity_state
    |> update_in([:current_status, Access.key(status_name, %{})], fn status ->
      Status.set_status(status, option)
    end)
  end
end

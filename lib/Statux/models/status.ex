defmodule Statux.Models.Status do
  @moduledoc """
  Represents the current and historic Status
  """
  use StructAccess
  use TypedStruct

  typedstruct do
    # The current status, e.g. :low, :critical
    field :current, atom()
    # if a transition occurs, it is added to the history like {%DateTime{}, :status_name}
    field :history, list, default: []
    # counts the number of times this status transitioned
    field :transition_count, Integer.t(), default: 0

    field :transitioned_at, DateTime.t()
  end

  # TODO: Add start/end time to history, e.g. {:low, %DateTime{}, %DateTime{} | nil}
  def set_status(nil, option) do
    %__MODULE__{
      current: option,
      transitioned_at: DateTime.utc_now(),
      transition_count: 1
    }
  end

  def set_status(%__MODULE__{current: current_option} = status, option) do
    case current_option == option do
      true -> status
      false ->
        %{
          status |
            current: option,
            transitioned_at: DateTime.utc_now(),
            transition_count: status.transition_count + 1,
            history: [option | status.history]
        }
    end
  end
end

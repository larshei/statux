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
  end
end

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

  def transition(data, option) do
    transition(data, option, DateTime.utc_now())
  end

  def transition(nil, option, datetime) do
    %__MODULE__{
      current: option,
      transitioned_at: datetime,
      transition_count: 1
    }
  end

  def transition(%__MODULE__{current: current_option} = status, option, datetime) do
    case current_option == option do
      true -> status
      false -> update_status(status, option, datetime)
    end
  end

  # no history, has never transitioned before.
  defp update_status(%__MODULE__{current: nil, history: []} = status, option, datetime) do
    %{
      status |
        current: option,
        transitioned_at: datetime,
        transition_count: 1,
    }
  end

  # no history, but has transitioned before
  defp update_status(
    %__MODULE__{
      current: transition_from,
      history: [],
      transitioned_at: transitioned_at
    } = status,
    option,
    datetime
  ) do
    %{
      status |
        current: option,
        transitioned_at: datetime,
        transition_count: status.transition_count + 1,
        history: [{transition_from, transitioned_at, nil}]
    }
  end

  # Has previously transitioned and a history -> update previous entry to add an end DateTime
  defp update_status(
    %__MODULE__{
      current: transition_from,
      history: [{previous_option, previous_started_at, _} | older_history],
      transitioned_at: transitioned_at
    } = status,
    option,
    datetime
  ) do
    %{
      status |
        current: option,
        transitioned_at: datetime,
        transition_count: status.transition_count + 1,
        history: [{transition_from, transitioned_at, nil}, {previous_option, previous_started_at, transitioned_at} | older_history]
    }
  end
end

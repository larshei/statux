defmodule Statux.Models.TrackingData do
  @moduledoc """
  This Structure holds data that is required to track :count or :duration constraints.
  It is updated whenever new data comes in and is used to decide wether or not a
  state can be transitioned into.
  """
  use StructAccess
  use TypedStruct

  typedstruct do
    # To check :count constraints like :min, :max, :is, :not, :gt, :lt.
    # These constraints expect a number of consecutive message fulfilling
    # the value requirements. If a message comes in that does not fulfill
    # the value requirements, the count is reset
    field :consecutive_message_count, Integer.t(), default: 0

    # To check :duration constraints like :min, :max, :is, :not, :gt, :lt.
    # Is set whenever the first consecutive message is received.
    # TODO: How to use with n_of_m constraints?
    field :datetime_first_consecutive_message, DateTime.t()

    # indicates wether an n_of_m constraint is used
    field :n_of_m_constraint, list(), default: nil

    # If n_of_m constraint is used, this holds the result of the last
    # m values. Otherwise, the list remains empty.
    field :valid_history, list(boolean()), default: []

    # If n_of_m is used, this holds the cound of `true` elements in
    # the :valid_history (so we d oont have to count every time)
    field :valid_history_true_count, Integer.t(), default: 0
  end

  def put_valid(%__MODULE__{
    n_of_m_constraint: nil,
    consecutive_message_count: 0,
    } = tracking_data
  ) do
    tracking_data
    |> Map.put(:consecutive_message_count, 1)
    |> Map.put(:datetime_first_consecutive_message, DateTime.utc_now())
  end

  def put_valid(%__MODULE__{
    n_of_m_constraint: nil,
    consecutive_message_count: n,
    } = tracking_data
  ) do
    tracking_data
    |> Map.put(:consecutive_message_count, n + 1)
  end

  def put_valid(%__MODULE__{
    n_of_m_constraint: [_n, m],
    valid_history: history,
    valid_history_true_count: history_count,
    consecutive_message_count: count,
    datetime_first_consecutive_message: datetime_first_consecutive_message,
    } = tracking_data)
  do
    updated_history_true_count =
      case history |> Enum.at(m - 1) do
        true -> history_count
        _ -> history_count + 1 # false or nil
      end

    updated_datetime_first_consecutive_message =
      case count do
        0 -> DateTime.utc_now()
        _ -> datetime_first_consecutive_message
      end

    updated_history =
      [true | Enum.take(history, m - 1)]

    tracking_data
    |> Map.put(:consecutive_message_count, count + 1)
    |> Map.put(:datetime_first_consecutive_message, updated_datetime_first_consecutive_message)
    |> Map.put(:valid_history_true_count, updated_history_true_count)
    |> Map.put(:valid_history, updated_history)
  end


  def put_invalid(%__MODULE__{n_of_m_constraint: nil} = tracking_data) do
    tracking_data
    |> Map.put(:consecutive_message_count, 0)
    |> Map.put(:datetime_first_consecutive_message, nil)
  end

  def put_invalid(%__MODULE__{n_of_m_constraint: [_n, m], valid_history: history, valid_history_true_count: history_count} = tracking_data) do
    updated_history_true_count =
      case history |> Enum.at(m - 1) do
        true -> history_count - 1
        _ -> history_count # false or nil
      end

    updated_history =
      [false | Enum.take(history, m - 1)]

    tracking_data
    |> Map.put(:consecutive_message_count, 0)
    |> Map.put(:datetime_first_consecutive_message, nil)
    |> Map.put(:valid_history_true_count, updated_history_true_count)
    |> Map.put(:valid_history, updated_history)
  end
end

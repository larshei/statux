defmodule Statux do
  @moduledoc """

  """
  defdelegate child_spec(opts), to: Statux.Tracker

  def init(init_arg) do
    {:ok, init_arg}
  end

  @doc """
  Pass a new value to Statux to be evaluated against the given rule_set

  Feedback is provided asynchronously, either through the configured PubSub Module or by calling
  the callbacks given in the rule set.

      Statux.put("my_device", :battery_voltage, 12.4)
  """
  def put(id, status_name, value, rule_set \\ :default) do
    Statux.Tracker.put(id, status_name, value, rule_set)
  end

  @doc """
  Retrieve the current status for a given ID.

      iex> Statux.get("my_device")
      %{
        battery_voltage: %Statux.Models.Status{
          current: :ok,
          history: [:ok, :low],
          transition_count: 2,
          transitioned_at: DateTime%{}
        },
        other_status: %Statux.Models.Status{...},
        ...
      }
  """
  def get(id) do
    Statux.Tracker.get(id)
  end

  @doc """
  Forcefully sets the state of a given id and status to an option.

  This allows to create options that can not be left automatically, for example
  a :critical or :warning status that has to be acknowledged manually.

      iex> Statux.put("my_device", :battery_voltage, :ok)
      %Statux.Models.Status{
        current: :ok,
        history: [:ok, :low],
        transition_count: 2,
        transitioned_at: DateTime%{} # now
      }

      iex> Statux.put("my_device", :battery_voltage, :some_random_option)
      {:error, :invalid_option}
  """
  def set(id, status_name, option) do
    Statux.Tracker.set(id, status_name, option)
  end
end

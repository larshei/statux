defmodule Statux do
  @moduledoc """
  Contains the public API for Statux.
  """

  @doc """
  Create a Statux Server to track the Status of entities.

  For now, there is not much to configure.

  Configure using

      config :statux,
        rule_set_file: "path/to/file.json",
        pubsub: MyApp.PubSub    # optional

  """
  # TODO: Pass args for e.g. Rule Set(s), PubSub name or Process name
  def start_link(_) do
    Statux.Tracker.start_link([])
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  @doc """
  Pass a new value to Statux to be evaluated against the given rule_set

  Feedback is provided asynchronously, either through the configured PubSub Module or by calling
  the callbacks given in the rule set.

      Statux.put("my_device", :battery_voltage, 12.4)
  """
  def put(id, status_name, value) do
    Statux.Tracker.put(id, status_name, value)
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

      iex> Statux.put("my_device", :battery_voltage, :ok)
      :error
  """
  def set(id, status_name, option) do
    Statux.Tracker.set(id, status_name, option)
  end
end

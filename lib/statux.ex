defmodule Statux do
  @moduledoc """
  The Statux library can be used to evaluate given key-value pairs to states.
  """
  defdelegate child_spec(opts), to: Statux.Tracker

  def load_rule_set!(path), do: Statux.RuleSet.load_json!(path)

  def init(init_arg) do
    {:ok, init_arg}
  end

  @doc """
  Simply evaluates the given value for the given status based on its value.
  This function can be used to have a simple rule evaluation without any additional constraints.
  Therefore, 'constraints' are ignored and only the 'value' requirements are evaluated.
  """
  def run(status_name, value, rule_set) do
    status_options =
      rule_set[status_name][:status]

    case Statux.ValueRules.should_be_ignored?(value, rule_set[status_name]) do
      true -> []
      _ -> Statux.ValueRules.find_possible_valid_status(value, status_options)
    end
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
  Pass a new value to a specific Statux process.
  Refer to put/4 for more information.
  """
  def put_for(server, id, status_name, value, rule_set \\ :default) do
    Statux.Tracker.put(server, id, status_name, value, rule_set)
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
  Get the tracked status of a given id from a specific Statux process.
  """
  def get_for(server, id) do
    Statux.Tracker.get(server, id)
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

  @doc """
  Force-sets the status for the given id on a specific server.
  See set/3 for more information.
  """
  def set_for(server, id, status_name, option) do
    Statux.Tracker.set(server, id, status_name, option)
  end
end

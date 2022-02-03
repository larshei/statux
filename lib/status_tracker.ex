defmodule StatusTracker do
  use GenServer
  require Logger

  @moduledoc """
  The StatusTracker allows to track status for different ids over time and
  transition from a status to another status based on configured rules.

  The interface is very simple and if a change in status occurs, a message is
  broadcasted via PubSub.

  ## Basic Usage

  On receiving a new value for the `:battery_voltage` of device _my_device_1_,
  you can update the devices status tracking using `put/3`:

      StatusTracker.put("my_device_1", :battery_voltage, 11.4)

  If the status of the device changes, e.g. from `:normal` to `:critical`, a
  PubSub message is broadcasted on topic `"StatusTracker"` that you may handle
  in a handle_info():

      def init(_) do
        Phoenix.PubSub.subscribe(MyApp.PubSub, "StatusTracker")
        [...]
      end

      def handle_info({:transitioned, "my_device_1", :battery_voltage, :critical, 11.4}) do
        # Handle the update here
      end

  ## Initializing the StatusTracker

  1. Add the StatusTracker and PubSub to your dependencies in mix.exs
    ```
    def deps() do
      [
        {:status_tracker, "~> 0.1.0"},
        {:phoenix_pubsub, "~> 2.0"},
      ]
    end
    ```

  2. Start the Process and PubSub in your Application.ex by adding them to the
     Supervision tree in your Application.ex.

     ```
      use Application

      @impl true
      def start(_type, _args) do
        children = [
          {Phoenix.PubSub, name: MyApp.PubSub},
          StatusTracker,
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end
     ```

  ## Example Rule Set

      %{
        battery_voltage: %{
          ok: %{
            value: %{min: 11.9},
            constraints: %{
              count: %{min: 3}
            }
          },
          low: %{
            value: %{lt: 11.9, min: 11.5},
            constraints: %{
              count: %{min: 3},
              duration: %{min: "PT10S" |> Timex.Duration.parse!}
            }
          },
          critical: %{
            value: %{lt: 11.5}
          }
        },
      }

  ## Updating the Status

  The example Rule Set has a property `:battery_voltage`.



  In this example, we should trigger the status `:critical`, if it was not
  critical already. A transition will be broadcasted through PubSub, that you
  can handle in `handle_info/3` in Processes subscribed to "StatusTracker".


  """

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def put(id, status, value) do
    GenServer.cast(__MODULE__, {:put, id, status, value})
  end

  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  # Callbacks
  @impl true
  def init(_) do
    # TODO: read from file.
    # currently ignored, read from rules() instead in handle_cast().
    path = case Application.get_env(:status_tracker, :rule_set_file) do
      nil -> raise "Missing configuration file for StatusTracker. Configure as :status_tracker, :rule_set_file."
      path -> path |> Path.expand
    end

    rules =
      case path != nil and File.exists?(path) do
        true ->
          IO.puts "reading #{path |> Path.expand}"
          StatusTracker.RuleSet.load_json!(path)
        false ->
          raise "Missing configuration file for StatusTracker. Expected at '#{path}'. Configure as :status_tracker, :rule_set_file."
      end

    pubsub = Application.get_env(:status_tracker, :pubsub)

    if pubsub == nil do
      Logger.warn("No PubSub configured for StatusTracker. Configure as :status_tracker, :pubsub.")
    end

    {:ok, %{rules: rules, states: %{}, pubsub: pubsub}}
  end

  def process_new_data(data, id, status_name, value) do
    rules_for_status = data.rules[status_name] || %{}

    state = data.states[id][status_name] || %{pending: nil, history: []}

    maybe_new_status =
      StatusTracker.ValueRules.find_valid_state(value, rules_for_status) || :unknown

    {has_transitioned?, new_status} =
      StatusTracker.Constraints.validate(maybe_new_status, state, rules_for_status[maybe_new_status][:constraints])

    if has_transitioned? and data.pubsub != nil do
      {_transitioned_at, transition_to} = new_status.history |> hd()
      Phoenix.PubSub.broadcast!(data.pubsub, "StatusTracker", {:transitioned, id, status_name, transition_to, value})
    end

    new_data = put_in(data, [:states, Access.key(id, %{}), status_name], new_status)

    new_data
  end

  @impl true
  def handle_cast({:put, id, status_name, value} = _message, data) do
    {:noreply, data |> process_new_data(id, status_name, value)}
  end

  @impl true
  def handle_cast(_message, data) do
    {:noreply, data}
  end

  @impl true
  def handle_call({:get, id}, _from_pid, state) do
    {:reply, state.states[id], state}
  end

end

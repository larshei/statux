defmodule Statux.Tracker do
  use GenServer
  require Logger

  alias Statux.Models.EntityStatus
  alias Statux.Models.Status

  def start_link(_) do
    GenServer.start_link(__MODULE__, %Statux.Models.TrackerState{}, name: __MODULE__)
  end

  def put(id, status_name, value) do
    GenServer.cast(__MODULE__, {:put, id, status_name, value})
  end

  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  def set(id, status_name, option) do
    GenServer.call(__MODULE__, {:set, id, status_name, option})
  end

  # CALLBACKS
  @impl true
  def init(_) do
    # TODO: read from file.
    # currently ignored, read from rules() instead in handle_cast().
    path = case Application.get_env(:statux, :rule_set_file) do
      nil -> raise "Missing configuration file for Statux. Configure as :status_tracker, :rule_set_file."
      path -> path |> Path.expand
    end

    rules =
      case path != nil and File.exists?(path) do
        true ->
          Statux.RuleSet.load_json!(path)
        false ->
          raise "Missing configuration file for Statux. Expected at '#{path}'. Configure as :statux, :rule_set_file."
      end

    pubsub = Application.get_env(:statux, :pubsub)

    if pubsub == nil do
      Logger.warn("No PubSub configured for Statux. Configure as :statux, :pubsub.")
    end

    {:ok, %{rules: rules, states: %{}, pubsub: pubsub}}
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
    {:reply, state.states[id][:current_stats], state}
  end

  @impl true
  def handle_call({:set, id, status_name, option}, _from_pid, state) do
    current_status = state.states[id][:current_stats][status_name]

    updated_status =
      Status.set_status(current_status, option)

    {:reply, updated_status, state |> put_in([:states, id, :current_stats, status_name], updated_status)}
  end

  # Data processing
  def process_new_data(data, id, status_name, value, rule_set_name \\ :default) do
    rule_set = data.rules[rule_set_name] || data.rules[:default] || %{}

    cond do
      # no status with this name
      rule_set[status_name] == nil -> data
      # value should be ignored
      Statux.ValueRules.should_be_ignored?(value, rule_set[status_name]) -> data
      # process the value
      true -> data |> evaluate_new_status(id, status_name, value, rule_set)
    end
  end

  defp evaluate_new_status(data, id, status_name, value, rule_set) do
    entity_status =
      data.states[id] || EntityStatus.new_from_rule_set(id, rule_set)

    status_options =
      rule_set[status_name][:status]

    case status_options do
      nil -> data
      _ ->
        valid_options_for_value = value
        |> Statux.ValueRules.find_possible_valid_status(status_options)

        updated_entity_status = entity_status
        |> Statux.Entities.update_tracking_data(status_name, status_options, valid_options_for_value)

        transitions = updated_entity_status
        |> Statux.Constraints.filter_valid_transition_options(status_name, status_options, valid_options_for_value)

        transitioned_entity_status = updated_entity_status
        |> Statux.Transitions.transition(status_name, transitions)

        put_in(data, [:states, id], transitioned_entity_status)
    end


    # |> Statux.Constraints.filter_constraints_fulfilled(entity_state, status_constraints)
  # |> Publish update if transitioned
  # |> Update state

    # if has_transitioned? and data.pubsub != nil do
    #   {_transitioned_at, transition_to} = new_status.history |> hd()
    #   Phoenix.PubSub.broadcast!(data.pubsub, "Statux", {:transitioned, id, status_name, transition_to, value})
    # end

  end

end

defmodule Statux.Tracker do
  use GenServer
  require Logger

  alias Statux.Models.EntityStatus
  alias Statux.Models.Status

  def start_link(args) do
    GenServer.start_link(
      __MODULE__,
      args,
      name: args[:name] || __MODULE__
    )
  end

  def put(id, status_name, value, rule_set) do
    GenServer.cast(__MODULE__, {:put, id, status_name, value, rule_set})
  end

  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  def set(id, status_name, option) do
    GenServer.call(__MODULE__, {:set, id, status_name, option})
  end

  # CALLBACKS
  @impl true
  def init(args) do
    Logger.info("Starting #{__MODULE__}")

    path = case args[:rule_set_file] || Application.get_env(:statux, :rule_set_file) do
      nil -> raise "Missing configuration file for Statux. Configure as :status_tracker, :rule_set_file or pass as argument :rule_set_file"
      path -> path |> Path.expand
    end

    rules =
      case path != nil and File.exists?(path) do
        true ->
          Statux.RuleSet.load_json!(path)
        false ->
          raise "Missing configuration file for Statux. Expected at '#{path}'. Configure as :statux, :rule_set_file."
      end

    pubsub = args[:pubsub] || Application.get_env(:statux, :pubsub)

    topic =
      if pubsub == nil do
        Logger.warn("No PubSub configured for Statux. Configure as :statux, :pubsub or pass as argument :pubsub")
        nil
      else
        case args[:topic] || Application.get_env(:statux, :topic) do
          nil ->
            Logger.warn("No PubSub topic configured for Statux. Configure as :statux, :topic or pass as argument :topic. Defaulting to topic 'Statux'")
            "Statux"
          topic ->
            topic
        end
      end

    {:ok, %Statux.Models.TrackerState{rules: %{default: rules}, pubsub: %{module: pubsub, topic: topic}}}
  end

  @impl true
  def handle_cast({:put, id, status_name, value, rule_set} = _message, data) do
    {:noreply, data |> process_new_data(id, status_name, value, rule_set)}
  end

  @impl true
  def handle_cast(_message, data) do
    Logger.debug "#{__MODULE__} - handle_cast FALLBACK"
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
      rule_set[status_name] == nil ->
        Logger.debug "No rules for status '#{inspect status_name}' found"
        data
      # value should be ignored
      Statux.ValueRules.should_be_ignored?(value, rule_set[status_name]) ->
        Logger.debug "Value #{inspect value} is to be ignored for rule set '#{inspect status_name}'"
        data
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
        |> Statux.Transitions.transition(status_name, transitions, data.pubsub)

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

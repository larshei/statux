defmodule Statux.Tracker do
  use GenServer
  require Logger

  alias Statux.Models.EntityStatus
  alias Statux.Models.Status
  alias Statux.Models.TrackingData

  def start_link(args) do
    GenServer.start_link(
      __MODULE__,
      args,
      name: args[:name] || __MODULE__
    )
  end

  def put(server \\ __MODULE__, id, status_name, value, rule_set) do
    GenServer.cast(server, {:put, id, status_name, value, rule_set})
  end

  def get(server \\ __MODULE__, id) do
    GenServer.call(server, {:get, id})
  end

  def set(server \\ __MODULE__, id, status_name, option) do
    GenServer.call(server, {:set, id, status_name, option})
  end

  # CALLBACKS
  @impl true
  def init(args) do
    name = args[:name] || __MODULE__
    readable_name = case name do
      {:via, Registry, {_registry, name}} -> name
      {:global, name} -> name
      _ -> name
    end

    Logger.info("Starting #{__MODULE__} '#{inspect name}'")

    path = case args[:rule_set_file] || Application.get_env(:statux, :rule_set_file) do
      nil -> raise "Statux #{readable_name} - Missing configuration file for Statux. Configure as :statux, :rule_set_file or pass as argument :rule_set_file"
      path -> path |> Path.expand
    end

    rules =
      case path != nil and File.exists?(path) do
        true ->
          Statux.RuleSet.load_json!(path)
        false ->
          raise "Statux #{readable_name} - Missing configuration file for Statux. Expected at '#{path}'. Configure as :statux, :rule_set_file or pass as argument :rule_set_file."
      end

    pubsub = args[:pubsub] || Application.get_env(:statux, :pubsub)

    topic =
      if pubsub == nil do
        Logger.warn("Statux #{readable_name} - No PubSub configured for Statux. Configure as :statux, :pubsub or pass as argument :pubsub")
        nil
      else
        case args[:topic] || Application.get_env(:statux, :topic) do
          nil ->
            Logger.warn("Statux #{readable_name} - No PubSub topic configured for Statux. Configure as :statux, :topic or pass as argument :topic. Defaulting to topic 'Statux'")
            "Statux"
          topic ->
            topic
        end
      end

    persist? = args[:enable_persistence] || Application.get_env(:statux, :enable_persistence)
    folder = args[:persistence_folder] || Application.get_env(:statux, :persistence_folder)

    initial_states =
      case {persist?, folder} do
        {true, nil} ->
          raise "Statux #{readable_name}: You have enabled persistence, but did not provide a folder to persist data to. Configure as :statux, :persistence_folder or pass as argument :persistence_folder."
        {true, folder} ->
          Logger.info("Statux - Persistence is enabled, trying to read file for #{readable_name} from #{folder}")
          file_name = "#{folder}/#{readable_name}.dat"

          file_name
          |> String.replace("//", "/")
          |> File.exists?()
          |> case do
            false ->
              Logger.warn("Statux - Could not find existing state for #{readable_name} at #{folder}/#{readable_name}.dat. Creating empty state.")
              %{}
            true ->
              file_name
              |> File.read!()
              |> :erlang.binary_to_term()
          end
        _ -> %{}
      end

    Process.flag(:trap_exit, true)

    Logger.info("Statux - Successfully started for #{readable_name}")

    {
      :ok,
      %Statux.Models.TrackerState{
        name: readable_name,
        persistence: %{
          enabled: persist?,
          folder: folder,
        },
        pubsub: %{module: pubsub, topic: topic},
        rules: %{default: rules},
        states: initial_states,
      }
    }
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
    {:reply, state.states[id][:current_status], state}
  end

  @impl true
  def handle_call({:set, id, status_name, option}, _from_pid, state) do
    {updated_status, updated_state} =
      set_status(state, id, status_name, option)

    {:reply, updated_status, updated_state}
  end

  @impl true
  # For reasons I don't understand, this seems to never be called.
  def handle_info({:EXIT, _from, reason}, state) do
    Logger.warn("Statux #{state.name} - Exited with reason #{inspect reason}")
    maybe_persist_state(state)
    {:stop, reason, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.warn("Statux #{state.name} - Terminated with reason #{inspect reason}")
    maybe_persist_state(state)
    reason
  end

  defp maybe_persist_state(%{persistence: %{enabled: true, folder: folder}} = state) do
    path = "#{folder}/#{state.name}.dat"

    Logger.info("Statux #{state.name} - Persistence is enabled, persisting data under #{path}")

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, state.states |> :erlang.term_to_binary)
  end
  defp maybe_persist_state(state) do
    Logger.info("Statux #{state.name} - Persistence is disabled")
  end

  def set_status(state, id, status_name, option) do
    defined_options =
      state.rules[state.states[id][:rule_set_name] || :default][status_name][:status] |> Map.keys()

    valid_option? =
      option in defined_options

    case valid_option? do
      false ->
        {{:error, :invalid_option}, state}
      true ->
        updated_status =
          state.states[id][:current_status][status_name]
          |> Status.transition(option)

        updated_tracking =
          state.states[id][:tracking][status_name]
          |> Map.keys
          |> Enum.reduce(state.states[id][:tracking][status_name], fn option, tracking ->
            tracking
            |> update_in([option], fn option_tracking_data ->
              option_tracking_data
              |> TrackingData.reset()
            end)
          end)

        updated_state = state
        |> put_in([:states, id, :current_status, status_name], updated_status)
        |> put_in([:states, id, :tracking, status_name], updated_tracking)

        {updated_status, updated_state}
    end
  end

  # Data processing
  def process_new_data(data, id, status_name, value, rule_set_name \\ :default) do
    rule_set = data.rules[rule_set_name] || data.rules[:default] || %{}
    cond do
      # no status with this name
      rule_set[status_name] == nil ->
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
  end

end

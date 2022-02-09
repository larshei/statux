rule_set = Statux.RuleSet.load_json!("rule_set.json")
data = Statux.Models.TrackerState.new(rule_set)

alias Statux.Models.EntityStatus
alias Statux.Models.TrackingData
alias Statux.Models.TrackerState
alias Statux.Models.Status

# convenience functions for testing.

put = fn data, value -> Statux.Tracker.process_new_data(data, "my_device", :battery_voltage, value) end
get = fn data -> data.states["my_device"][:current_status] end
set = fn
  data, option ->
    current_status = data.states["my_device"][:current_status][:battery_voltage]

    updated_status =
      Status.set_status(current_status, option)

    {
      data |> put_in([:states, "my_device", :current_status, :battery_voltage], updated_status),
      updated_status
    }
end

rule_set = Statux.RuleSet.load_json!("rule_set.json")
data = Statux.Models.TrackerState.new(rule_set)

alias Statux.Models.EntityStatus
alias Statux.Models.TrackingData
alias Statux.Models.TrackerState
alias Statux.Models.Status

put = fn data, value -> Statux.Tracker.process_new_data(data, "lars", :battery_voltage, value) end

rules = %{
  battery_voltage: %{
    critical: %{
      constraints: %{count: %{min: 3}, duration: %{min: "PT1S" |> Timex.Duration.parse!}},
      value: %{lt: 11.8}
    },
    low: %{
      constraints: %{count: %{min: 3}, duration: %{min: "PT1S" |> Timex.Duration.parse!}},
      value: %{max: 12.0, min: 11.8}
    },
    ok: %{constraints: %{count: %{min: 3}}, value: %{gt: 12.1}}
  },
  other_voltage: %{
    critical: %{
      constraints: %{count: %{min: 3}, duration: %{min: "PT1S" |> Timex.Duration.parse!}},
      value: %{lt: 11.8}
    },
    low: %{
      constraints: %{count: %{min: 3}, duration: %{min: "PT1S" |> Timex.Duration.parse!}},
      value: %{max: 12.0, min: 11.8}
    },
    ok: %{constraints: %{count: %{min: 3}}, value: %{gt: 12.1}}
  }
}

battery_rules = rules.battery_voltage
constraints = rules.battery_voltage.ok.constraints

Benchee.run(
  %{
    "find_state_single" => fn -> Statux.ValueRules.find_possible_valid_status(10, battery_rules, [:critical]) end,
    "find_state_last" => fn -> Statux.ValueRules.find_possible_valid_status(10, battery_rules, [:ok, :low, :critical]) end,
  },
  time: 5,
  memory_time: 2
)

now = DateTime.utc_now()
pending_critical = %{pending: {now, :critical, 3}, history: []}
pending_critical_with_history = %{pending: {now, :critical, 3}, history: [{0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0}]}

Benchee.run(
  %{
    "validate_constraints" =>
      fn -> Statux.Constraints.validate(:ok, %{pending: {}, history: []}, rules) end,
    "validate_constraints_with_transition" =>
      fn -> Statux.Constraints.validate(:critical, pending_critical, rules) end,
    "validate_constraints_with_transition_and_history" =>
      fn -> Statux.Constraints.validate(:critical, pending_critical_with_history, rules) end,
  },
  time: 5,
  memory_time: 2
)

data = %{rules: rules, states: %{"1" => %{battery_voltage: %{pending: nil, history: []}}}, pubsub: nil}

Benchee.run(
  %{
    "battery_ok" => fn -> Statux.process_new_data(data, "1", :battery_voltage, 13) end,
    # "battery_critical" => fn -> Statux.process_new_data(data, "1", :battery_voltage, 9) end,
    # "other_ok" => fn -> Statux.process_new_data(data, "1", :other_voltage, 13) end,
    # "other_critical" => fn -> Statux.process_new_data(data, "1", :other_voltage, 9) end,
  },
  time: 5,
  memory_time: 2
)

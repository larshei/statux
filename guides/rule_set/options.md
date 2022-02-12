# Options for Rule Sets

## General Structure

A Rule Set has the following structure:

```none
Rule Set
├── Status Name 1
│   ├── ignore # optional
│   ├── Option 1
│   ├── Option 2
│   └── Option 3
└── Status Name 2
    ├── Option A
    └── Option B
```

1. The _Status Name_ is your referral or id for tracking and adding values. Example: _temperature_ or
_battery_voltage_.
2. An _Option_ could be something like _cold_, _warm_, _low_, _critical_. A Status can transition
   between it's options.
3. If you wish to _ignore_ values, you may set this up as well. If an ignored
   value is received, it is treated as if it was never received.

## Defining Constraints Options

### Available constraints

The basic constraints are:

- `min`: minimum, including. For numeric values and durations.
- `max`: maximum, including. For numeric values and durations.
- `lt`: less than. For numeric values and durations.
- `gt`: greater than. For numeric values and durations.
- `is`: a value or list of values
- `not`: a value or list of values
- `contains`: a value or string. For lists or strings. (to be implemented)
- `begins_with`: a value or string. For lists or strings. (to be implemented)
- `ends_with`: a value or string. For lists or strings. (to be implemented)

Specific constraints are 

- `n_of_m`: only for _constraints.count_. Can not be mixed with other constraints. This allows to set a
  constraint where n in the last m messages need to fullfil the value constraints.

### Constraints structure

You may define rules for each option to define when a transition to this option should occur.

```none
Option
├── value
│   └── min, max, is, not, lt, gt, contains, begins_with, ends_with
└── constraints
    ├── duration
    │   └── min, max, is, not, lt, gt
    ├── previous_status
    │   └──  is, not
    └── count
        └── n_of_m OR min, max, is, not, lt, gt
```

### How constraints are evaluated

For each Option, the constraints for _value_ are evaluated first.
If the check fails, the option is excluded from any further checks.

If the value constraints are fulfilled, Statux will update its internal state to remember that the
value passed the checks and is considered valid. It will then continue to check the other
constraints to see if a transition should happen or is blocked by _count_, _duration_ or
_previous_status_ constraints.

## Examples for Constraints

1. Check wether a value is in the range of 10 and 20 for at least 5 consecutive messages:

    ```none
    "option" {
      "value": {"min": 10, "max": 20},
      "constraints": {"count": {"min": 5}}
    }
    ```

2. Check wether a value has been in the range of 10 and 20 at least of 3 of 5 messages in the last 10
minutes:

    ```none
    "option" {
      "value": {"min": 10, "max": 20},
      "constraints": {"count": {"n_of_m": [3, 5]}, "duration": {"min": "PT10M"}}
    }
    ```

    Durations may be given as [ISO8601 Durations](https://www.digi.com/resources/documentation/digidocs/90001437-13/reference/r_iso_8601_duration_format.htm)
    or as a numeric value in seconds.

    > The duration is only evaluated when a message is received! It does not automatically transition
    > after a given time.

3. Check for specific values or exclude specific values.

    Valid only if the value is exactly `"hello world"`
    ```none
    "option" {
      "value": {"is": "hello world"},
    }
    ```

    Valid if the value contains `"hello"` but is not `"hello world"` or `"hello you"`.
    ```none
    "option" {
      "value": {"contains": "hello", "not": ["hello world", "hello you"]},
    }
    ```

## Examples Rule Set

Rule Set to track car battery voltages with.

```json
{
  "battery_voltage": {
    "ignore": {"value": {"is": null}},
    "status": {
      "critical": {
        "value": {"lt": 11.7}
        "constraints": {
          "count": {"min": 3},
          "duration": {"min": "PT10M"}
        },
      },
      "low": {
        "value": {"lt": 12.0, "min": 11.7}
        "constraints": {
          "count": {"min": 3},
          "duration": {"min": 300},
          "previous_status": {"not": "critical"}
        },
      },
      "ok": {
        "value": {"min": 12.0}
        "constraints": {
          "count": {"n_of_m": [3,5]},
          "previous_status": {"not": "critical"}
        },
}}}}
```

Note that the _critical_ state can not be left! It has to be left manually, e.g. by an operator who
confirms the issue was resolved and presses a button to force the state to be set to another value.

Blocking the exit of _critical_ might not be of most value here, but imagine a machine that stops
after a failure and needs repairs. It should not restart operation by itself but require someone to
manually start it, to make sure maintenance is completed and there is no person with their hands
inside the machine. 

# Getting started

Statux works based on configured rules.
The rules provide as a description of different states and when these states are valid.
Statux may be used to do single evaluations of data against rules or to track states through time
and add additional constraints. When used for single evaluations, you are mostly using it like a
library that provides some functions. For tracking state through time, Statux provides a Tracker
Process to hold state and communicates transitions through PubSub.

## Define a basic Rule Set

Rule sets describe the logic behind your Status and their transitions.

Here is a very basis rule set that we use to control our heating and cooling system at home that we
will use for the following examples:

```json
{
  "temperature": {
    "ignore": {"value": {"is": null}},
    "status": {
      "warm": {"value": {"min": 21.0}},
      "cold": {"value": {"max": 18.5}}
}}}
```

## Loading a Rule Set

    iex> rule_set = Statux.load_rule_set!("path/to.json")

The parser checks for errors and should raise with a comprehensive message when the Rule Set cannot
be loaded or parsed.

## Evaluating incoming data

On receiving a new dataset from our temperature sensor, we can use

    iex> Status.valid_states(:temperature, 20.5, rule_set)
    []
    iex> Status.valid_states(:temperature, 22.5, rule_set)
    [:warm]

> Note that all keys are transformed to atoms on parsing the Rule Set, so our identifier is
> `:temperature` and our return value is `:warm`. We see how to adjust the return value later.

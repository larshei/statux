# Getting started

Statux works based on configured rules. If there are no rules, there is nothing to be done.

## Define a Rule Set

Rule sets describe the logic behind your Status and their transitions.

Here is an example rule set as JSON:

```json
{
  "battery_voltage": {
    "ignore": {"value": {"is": null}},
    "status": {
      "good": {"value": {"min": 3.4}},
      "bad": {"value": {"lt": 3.4}}
}}}
```

JSON was chosen because its easily readable and editable for operations, for example with a
textarea and a button in a Phoenix project or as files on disks.

Store the JSON file somewhere and either pass it's file path to Statux on startup

    def start(_type, _args) do
      children = [
        {Statux, [rule_set_file: "rule_set.json", ...]},
      ]
      ...

or use your projects configuration

    # application.ex
    def start(_type, _args) do
      children = [
        Statux,
      ]
      ...

    # config file
    import Config
    config :statux,
      rule_set_file: "rule_set.json"


## Set up notifications

When you send data to Statux, it will happily accept them and move on, without any feedback.

Data is processes asynchronously, and if something happens that may be of interest to you, Statux
will publish this information through [Phoenix.PubSub](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html). 

Add PubSub to your project dependencies and supervision tree. Configure it for Statux. Again, you
may choose to set up the PubSub module name and the publishing topic as arguments or through your
config file:

    # application.ex
    def start(_type, _args) do
      children = [
        {Phoenix.PubSub, name: MyPubSub},
        {Statux, [rule_set_file: "rule_set.json", pubsub: MyPubSub, topic: "Statux"]}
      ]
      ...

## Test from IEX

    # Subscribe to updates
    iex> Phoenix.PubSub.subscribe("Statux")
    :ok
    # Publish a message; wait a bit; flush received messages
    iex(3)> Statux.put("my_device", :battery_voltage, 3.6); :timer.sleep(100); flush
    {:exit, :battery_voltage, nil, "my_device"}
    {:enter, :battery_voltage, :good, "my_device"}
    :ok

Your Statux is up an running.

# Tracking

Statux allows to track values over time, with state being held in its own GenServer that you start
in your supervision tree. You may either pass the required configurations as part of the child spec

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

## Configuration

Required configuration is only the `rule_set_file`, a path to a JSON file that contains the default
rule set.

Optional arguments are `:pubsub` and `:topic`, which you will need to set up if you plan to use
notifications.


## Adding data

During tracking, an identifier is passed to Statux in order to allow tracking multiple entities at
once. Data can be added like so:

    Statux.put("living_room", :temperature, 16.6)

and retrieved with

    Statux.get("living_room")

To load initial state of e.g. a web page, the get/1 function is very handy. To react to
status changes, notifications are a better fit.


## Notifications

Data is processed asynchronously, and if something happens that may be of interest to you, Statux
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

Using the rule set from the _getting started_ section:

    # Subscribe to updates
    iex> Phoenix.PubSub.subscribe("Statux")
    :ok
    # Publish a message; wait a bit; flush received messages
    iex(3)> Statux.put("living_room", :temperature, 16.6); :timer.sleep(100); flush
    {:exit, :temperature, nil, "living_room"}
    {:enter, :temperature, :cold, "living_room"}
    :ok

Your Statux including notifications is up an running.

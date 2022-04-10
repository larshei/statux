# Installation

Add Statux to your mix dependencies

    def deps do
      [
        {:statux, "~> ..."},
      ]
    end

If you want to use Statux only to check rules independently, without tracking values over time,
that is all you need.

However, if you want to track status over time and apply additional constraints, you will also need
to add Statux to your application's Supervisor, see chapter introduction/tracking.

    def start(_type, _args) do
      children = [
        # ...
        {Phoenix.PubSub, name: MyPubSub}
        {Statux, [rule_set_file: "rule_set.json", pubsub: MyPubSub, topic: "my_topic"]},
        # ...
      ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end

Note the `:rule_set_file`. We will get to that in the next chapter.
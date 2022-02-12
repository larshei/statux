# Installation

Add Statux to your mix dependencies

    def deps do
      [
        {:statux, "~> 0.1.0"},
      ]
    end

and to your application's Supervisor

    def start(_type, _args) do
      children = [
        # ...
        {Statux, [rule_set_file: "rule_set.json", pubsub: MyApp.PubSub, topic: "my_topic"]},
        # ...
      ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end

Note the `:rule_set_file`. We will get to that in the next chapter.
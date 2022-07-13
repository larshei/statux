# What is Statux

Statux is a rule engine that evaluates input key/value pairs and returns a "status" based on a rule
set. Rule sets can be created and evaluated dynamically, with standard comparison schemes like
equals, not-equals, any-of, none-of etc.

Additionally, Statux allows to track the status of entities over time based on configured, time or
count based constraints.
It abstracts all the state handling, you simply pass messages and get notified if a transition
happened.

## Usage Example - Simple Status

A basic rule set could be to assign users to customers based on their email address.
The rule set could be dynamically generated from a database and maybe look something like this
(well obviously, the database already contains all the information you need, so this would be an
unnecessary extra step, but its nice to see the idea):

    iex> rule_set = %{
      email: %{
        status: %{
          "my_company" => %{value: %{matches: ~r/.*@my-company.com/}},
          "my_company_aliases" => %{value: %{matches: ~r/.*\+.*@my-company.com/}},
          "your_company" => %{value: %{matches: ~r/.*@ur-company.com/}},
        }
      }
    }

    iex> Statux.run(:email, "lars@my-company.com", rule_set)
    ["my_company"]

    iex> Statux.run(:email, "lars+test@my-company.com", rule_set)
    ["my_company_aliases", "my_company"]

    iex> Statux.run(:email, "lars@somethingelse.com", rule_set)
    []

## Usage Example - Tracking Status

Imagine you are controlling your heating/cooling and ventilation with a
[nerves](https://hexdocs.pm/nerves/getting-started.html) powered device and some sensors.

A simple rule set could look like this:

    %{
      air_quality: %{
        status: %{
          good: %{value: %{min: 90}},
          ok: %{value: %{min: 70, lt: 90}}, # explicitly add lt: 90 as well!
          bad: %{value: %{lt: 70}},
      }}
      temperature: %{
        status: %{
          warm: %{value: %{gt: 21}},
          good: %{value: %{min: 18, max: 21}},
          cold: %{value: %{lt: 18}},
    }}}

Now, whenever new sensor data is received, you may pass this data to Statux to compare it to your
constraints:

    Statux.put("living_room", :temperature, 17)
    Statux.put("kitchen", :air_quality, 85)

Statux will respond to transitions by publishing messages to a pubsub, so you may receive
messages like

    {:exit, :temperature, :good, "living_room"}
    {:enter, :temperature, :cold, "living_room"}
    {:stay, :air_quality, :ok, "kitchen"}

and could subscribe to these updates in a Phoenix live view or in a GenServer that controls your heating and ventilation:

    receive do
      {:enter, :temperature, :cold, room_id} -> turn_on_heater(room_id)
      {:exit, :temperature, :cold, room_id} -> turn_off_heater(room_id)
      {:enter, :temperature, :warm, room_id} -> turn_on_ac(room_id)
      {:exit, :temperature, :warm, room_id} -> turn_off_ac(room_id)
      {:enter, :air_quality, :bad, room_id} -> turn_on_ventilation(room_id)
      {:enter, :air_quality, :good, room_id} -> turn_off_ventilation(room_id)
    end

So far, for the example above, there is no real reason to not just use a bunch of `if` statements
chained together. But when automating heating and ventilation, you may not want to activate or
stop those just because someone walked past your sensors and the values changed for a short time.
You want to track the data through time. You could do this by designing a regulated feedback loop
or, if something less sophisticated and mathematical is needed, by using Statux.

Additional constraints may be given, for example, the number of consecutive value updates or a minimum
duration for which the :value constraints must be fulfilled. Also, we might want to ignore
specific values like `nil`. Let's change the configuration to require at least 5 consecutive
messages to trigger a state change and also a minimum of 1 minute valid state for air quality and
10 minutes for temperature:

    %{
      air_quality: %{
        ignore: %{is: nil}
        status: %{
          good: %{value: %{min: 90}, constraints: {count: %{min: 5}, duration: %{min: "PT1M"}}}
          ok: %{value: %{min: 70, lt: 90}, constraints: {count: %{min: 5}, duration: %{min: "PT1M"}}}
          bad: %{value: %{lt: 70}, constraints: {count: %{min: 5}, duration: %{min: "PT1M"}}}
        }
      }
      temperature: %{
        ignore: %{is: nil}
        status: %{
          warm: %{value: %{gt: 21}, constraints: {count: %{min: 5}, duration: %{min: "PT10M"}}}
          good: %{value: %{min: 18, max: 21}, constraints: {count: %{min: 5}, duration: %{min: "PT10M"}}}
          cold: %{value: %{lt: 18}, constraints: {count: %{min: 5}, duration: %{min: "PT10M"}}}
        }
      }
    }

Your implementation remains the same and you can adjust the behaviour through the rules.

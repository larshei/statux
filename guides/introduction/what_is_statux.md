# What is Statux

Statux allows to track the status of entities based on configured constraints.
It abstracts all the state handling, you simply pass messages and get notified if a transition
happened.

## Usage Example

Imagine you are controlling your heating/cooling and ventilation with a
[nerves](https://hexdocs.pm/nerves/getting-started.html) powered device and some sensors.

A simple rule set could look like this:

    %{
      air_quality: %{ # what value do we track?
        status: %{    # what are possible status for this value?
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

and could control your heating and ventilation by simply implementing a GenServer handle_info or
a Process with a receive loop

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

Additional constraints may be given, for example, the number of consecutive messages or a minimum
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

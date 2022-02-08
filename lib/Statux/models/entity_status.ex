defmodule Statux.Models.EntityStatus do
  alias Statux.Models.Status
  alias Statux.Models.TrackingData
  @moduledoc """
  Using the `Status.put/3` function to put a new value
  ```
  Status.put(id, status_name, value)
  ```
  you pass in an id.
  This struct holds the current tracking state for the given id as used by the
  Status Tracker internally.
  """
  use StructAccess
  use TypedStruct

  typedstruct do
    field :id, any()
    field :current_status, map(), default: %{}
    field :message_count, map(), default: %{}
    field :tracking, map(), default: %{}
  end

  def new_from_rule_set(id, rule_set) do
    rule_set
    |> Map.keys()
    # Add each rule to the tracking, like :battery_voltage or :speed
    |> Enum.reduce(%__MODULE__{id: id}, fn status_name, entity_status ->
      allowed_options =
        rule_set[status_name][:status]
        |> Map.keys()

      allowed_options
      # Add %Status for each option like :low, :ok, :critical to the rule tracking
      |> Enum.reduce(entity_status, fn option, updated_entity_status ->
        n_of_m_constraint =
          rule_set[status_name][:status][option][:constraints][:count][:n_of_m] # nil or [n, m]

        updated_entity_status
        |> put_in(
          [:tracking, Access.key(status_name, %{}), option ],
          %TrackingData{n_of_m_constraint: n_of_m_constraint}
        )
      end)
      |> put_in([:current_status, status_name], %Status{})
      |> put_in([:message_count, status_name], 0)
    end)
  end
end

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
    field :current_status, map(), default: %{}
    field :id, any()
    field :message_count, map(), default: %{}
    field :rule_set_name, any(), default: :default
    field :tracking, map(), default: %{}
  end

  def new_from_rule_set(id, rule_set, rule_set_name \\ :default) do
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
        updated_entity_status |> put_in(
          [:tracking, Access.key(status_name, %{}), option],
          TrackingData.from_option(rule_set[status_name][:status][option])
        )
      end)
      |> put_in([:current_status, status_name], %Status{})
      |> put_in([:message_count, status_name], 0)
    end)
    |> Map.put(:rule_set_name, rule_set_name)
  end

  def ensure_has_tracking_for_option(entity_state, status_name, status_options, option) do
    case entity_state.tracking[status_name][option] do
      nil -> entity_state |> put_in([:tracking, status_name, option], TrackingData.from_option(status_options))
      _ -> entity_state
    end
  end
end

defmodule Statux.Entities do
  alias Statux.Models.EntityStatus
  alias Statux.Models.TrackingData

  def update_tracking_data(possible_new_status, status_name, %EntityStatus{} = entity_status) do
    entity_status
    |> update_in([:tracking, status_name], fn tracking_for_status ->
      tracking_for_status
      |> Map.keys
      |> Enum.reduce(tracking_for_status, fn option, status ->
        updated_data =
          case option in possible_new_status do
            true -> TrackingData.put_valid(status[option])
            false -> TrackingData.put_invalid(status[option])
          end

        Map.put(status, option, updated_data)
      end)
    end)
  end
end

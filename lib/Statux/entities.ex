defmodule Statux.Entities do
  alias Statux.Models.EntityStatus
  alias Statux.Models.TrackingData

  def update_tracking_data([], _status_name, %EntityStatus{} = entity_status), do: entity_status
  def update_tracking_data(possible_valid_options, status_name, status_options, %EntityStatus{} = entity_status) do
    entity_status
    |> ensure_has_tracking_for_options(status_name, status_options, possible_valid_options)
    |> update_in([:tracking, status_name], fn tracking_for_status ->
      tracking_for_status
      |> Map.keys
      |> Enum.reduce(tracking_for_status, fn option, status ->
        updated_data =
          case option in possible_valid_options do
            true -> TrackingData.put_valid(status[option])
            false -> TrackingData.put_invalid(status[option])
          end

        Map.put(status, option, updated_data)
      end)
    end)
  end

  defp ensure_has_tracking_for_options(entity_state, _status_name, _status_options, []) do
    entity_state
  end

  defp ensure_has_tracking_for_options(entity_state, status_name, status_options, options) when is_list(options) do
    options
    |> Enum.reduce(entity_state, fn option, updated_entity_state ->
      updated_entity_state
      |> ensure_has_tracking_for_options(status_name, status_options, option)
    end)
  end

  defp ensure_has_tracking_for_options(entity_state, status_name, status_options, option) when is_atom(option) do
    case entity_state.tracking[status_name][option] do
      nil -> entity_state |> put_in([:tracking, status_name, option], TrackingData.from_option(status_options))
      _ -> entity_state
    end
  end
end

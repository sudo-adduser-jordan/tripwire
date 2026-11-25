defmodule TripwireWeb.PresenceHelpers do
  def presence(%{eve_id: eve_id}, presences), do: Map.get(presences || %{}, eve_id, %{})

  def presence_field(presences, character, key),
    do: Map.get(presence(character, presences), key)
end

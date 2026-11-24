defmodule Tripwire.Demo.State do
  defstruct character: nil,
            mask: nil,
            maps: [],
            systems: [],
            connections: [],
            signatures: [],
            comments: [],
            flares: [],
            stats: [],
            members: %{},
            settings: nil,
            layouts: [],
            next_id: 1,
            tracking?: true

  def take_id(%__MODULE__{} = state) do
    {state.next_id, %{state | next_id: state.next_id + 1}}
  end
end

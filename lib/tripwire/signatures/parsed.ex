defmodule Tripwire.Signatures.Parsed do
  @moduledoc """
  A single signature parsed out of an EVE probe-scan paste.
  """

  defstruct [:sig_id, :kind, :name, :wormhole_type, :category]

  @type category :: :combat | :data | :relic | :gas | :ore | :wormhole | :unknown
  @type kind :: :anomaly | :signature

  @type t :: %__MODULE__{
          sig_id: String.t(),
          kind: kind(),
          name: String.t() | nil,
          wormhole_type: String.t() | nil,
          category: category()
        }
end

defmodule Ztripwire.Signatures.Parsed do
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

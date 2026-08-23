defmodule Tripwire.EctoTypes.EncryptedBinary do
  use Cloak.Ecto.Binary, vault: Tripwire.Vault
end

defmodule Ztripwire.EctoTypes.EncryptedBinary do
  use Cloak.Ecto.Binary, vault: Ztripwire.Vault
end

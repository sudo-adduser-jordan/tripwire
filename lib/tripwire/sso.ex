defmodule Tripwire.SSO do
  @client_id_vars ~w(EVESSO_CLIENT_ID)
  @client_secret_vars ~w(EVESSO_SECRET_KEY EVESSO_CLIENT_SECRET)

  def configured?, do: credential?(@client_id_vars) and credential?(@client_secret_vars)

  def demo?, do: not configured?()

  def client_secret, do: first_env(@client_secret_vars)

  defp credential?(vars), do: present?(first_env(vars))

  defp first_env(vars), do: Enum.find_value(vars, &System.get_env/1)

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end

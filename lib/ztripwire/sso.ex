defmodule Ztripwire.SSO do
  @client_id_vars ~w(EVESSO_CLIENT_ID)
  @client_secret_vars ~w(EVESSO_SECRET_KEY EVESSO_CLIENT_SECRET)
  @state_cookie "ueberauth.state_param"

  def configured?, do: credential?(@client_id_vars) and credential?(@client_secret_vars)

  def demo?, do: not configured?()

  def client_id, do: first_env(@client_id_vars)

  def client_secret, do: first_env(@client_secret_vars)

  def state_param(conn) do
    conn = Plug.Conn.fetch_cookies(conn, signed: [@state_cookie])
    conn.cookies[@state_cookie]
  end

  defp credential?(vars), do: present?(first_env(vars))

  defp first_env(vars), do: Enum.find_value(vars, &System.get_env/1)

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end

defmodule Tripwire.Systems do
  @moduledoc """
  System-class resolution mirroring official Tripwire node content.

  Official Tripwire renders each chain-map node as class (top), system
  name or J-code (middle), and wormhole type (bottom). The class comes
  from its EVE dump when known (`C1`–`C6`, …); otherwise it falls back
  to security status: `HS` (`>= 0.45`), `LS` (`> 0.0`), `NS` (`<= 0.0`).

  This port stores `sys_class` (exact label, e.g. `"C3"`) and `security`
  (ESI `security_status`) on each map system. The security fallback only
  applies to known-space (`security >= 0`); wormhole systems without a
  known class render a blank class line instead of being mislabeled `NS`.
  """

  @doc """
  Returns the class label for a map system (`"C3"`, `"HS"`, `"LS"`,
  `"NS"`) or `nil` when unknown.
  """
  def display_class(%{sys_class: class}) when is_binary(class) and class != "", do: class
  def display_class(%{security: security}) when is_number(security) and security >= 0.45, do: "HS"
  def display_class(%{security: security}) when is_number(security) and security > 0.0, do: "LS"
  def display_class(%{security: security}) when is_number(security) and security >= 0.0, do: "NS"
  def display_class(_), do: nil

  @doc """
  Builds system attributes from an ESI `GET /universe/systems/{id}/`
  response body.
  """
  def attrs_from_esi(%{"name" => name} = body) do
    %{name: name, security: body["security_status"]}
  end

  def attrs_from_esi(_), do: %{name: nil, security: nil}
end

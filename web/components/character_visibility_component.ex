defmodule TripwireWeb.CharacterVisibilityComponents do
  use Phoenix.Component

  import TripwireWeb.IconComponent

  alias Tripwire.EveImages

  @doc """

  Renders the ship and character visibility toggle buttons for a character.

  The ship button shows the character's current ship render when known and a
  neutral cube icon otherwise. The character button uses the character's
  portrait. Hidden state is indicated by a dimmed visual.

  ## Examples

      <.character_visibility_buttons character={character} />

  """

  attr :character, :map, required: true
  attr :current_character, :any, default: nil
  attr :current_ship_type_id, :any, default: nil

  def character_visibility_buttons(assigns) do
    assigns =
      assign_new(assigns, :ship_img, fn ->
        ship_render(
          assigns.character,
          assigns[:current_character],
          assigns[:current_ship_type_id]
        )
      end)

    ~H"""
    <button
      type="button"
      phx-click="toggle-ship-visibility"
      phx-value-id={@character.id}
      title={ship_title(@character)}
      class="btn btn-ghost btn-xs shrink-0 p-1"
    >
      <img
        :if={@ship_img}
        src={@ship_img}
        alt=""
        loading="lazy"
        class={["size-4", !@character.ship_on_chain && "opacity-40"]}
        onerror="this.onerror=null;this.style.display='none'"
      />
      <.icon
        :if={!@ship_img}
        name="hero-cube"
        class={["size-4", !@character.ship_on_chain && "opacity-40"]}
      />
    </button>
    <button
      type="button"
      phx-click="toggle-character-visibility"
      phx-value-id={@character.id}
      title={character_title(@character)}
      class="btn btn-ghost btn-xs shrink-0 p-1"
    >
      <img
        src={portrait(@character)}
        alt=""
        loading="lazy"
        class={["size-4 rounded-full", !@character.character_on_chain && "opacity-40"]}
        onerror="this.onerror=null;this.src='/images/alliance-default.png'"
      />
    </button>
    """
  end

  defp ship_render(%{eve_id: eve_id}, %{eve_id: current_eve_id}, ship_type_id)
       when eve_id == current_eve_id and is_integer(ship_type_id) and ship_type_id > 0,
       do: EveImages.type_render(ship_type_id, 64)

  defp ship_render(_, _, _), do: nil

  defp portrait(%{eve_id: eve_id}) when is_integer(eve_id) and eve_id > 0,
    do: EveImages.character_portrait(eve_id, 32)

  defp portrait(_), do: "/images/alliance-default.png"

  defp ship_title(%{ship_on_chain: false, name: name}), do: "Show #{name}'s ship on chain"
  defp ship_title(%{name: name}), do: "Hide #{name}'s ship on chain"

  defp character_title(%{character_on_chain: false, name: name}),
    do: "Show #{name} on chain"

  defp character_title(%{name: name}),
    do: "Hide #{name}'s character and ship on chain"
end

defmodule TripwireWeb.MaskAvatarComponents do
  use Phoenix.Component

  alias Tripwire.EveImages

  attr :mask, :map, required: true
  attr :dot, :string, default: "avatar-offline"
  attr :size, :string, default: "sm", values: ["sm", "lg"]

  def mask_avatar(assigns) do
    ~H"""
    <div class={["avatar shrink-0", @dot]}>
      <div class={avatar_class(@size)}>
        <img
          src={mask_image(@mask)}
          alt=""
          loading="lazy"
          onerror="this.onerror=null;this.src='/images/alliance-default.png'"
        />
      </div>
    </div>
    """
  end

  def mask_image(%{kind: "corporation", eve_owner_id: id}) when is_integer(id),
    do: EveImages.corporation_logo(id, 64)

  def mask_image(%{kind: "alliance", eve_owner_id: id}) when is_integer(id),
    do: EveImages.alliance_logo(id, 64)

  def mask_image(_), do: "/images/alliance-default.png"

  defp avatar_class("lg"), do: "w-12 rounded-xl"
  defp avatar_class(_), do: "w-8 rounded-lg"
end

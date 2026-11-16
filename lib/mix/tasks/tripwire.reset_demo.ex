defmodule Mix.Tasks.Tripwire.ResetDemo do
  use Mix.Task

  @shortdoc "Clears demo maps and rebuilds demo data"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, mask} = Tripwire.Masks.ensure_demo_mask()
    {:ok, _map} = Tripwire.Mapping.reset_demo_maps(mask.id)

    Mix.shell().info("Demo data rebuilt for mask #{mask.id}")
  end
end

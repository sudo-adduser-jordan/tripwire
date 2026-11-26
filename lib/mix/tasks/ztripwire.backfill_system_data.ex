defmodule Mix.Tasks.Ztripwire.BackfillSystemData do
  use Mix.Task

  @shortdoc "Fill missing system class, effect and statics from priv/data/wormhole_systems.json"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [force: :boolean])
    force? = Keyword.get(opts, :force, false)

    updated = Ztripwire.Mapping.SystemData.backfill(force?)
    Mix.shell().info("Filled class, effect and statics on #{updated} map systems")
  end
end

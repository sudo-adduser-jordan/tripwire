defmodule Mix.Tasks.Tripwire.SyncSde do
  use Mix.Task

  @shortdoc "Load EVE static data into the sde_* tables"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [sde: :string, force: :boolean])

    case Tripwire.Sde.Sync.run(opts) do
      :ok ->
        Mix.shell().info("SDE tables synced")

      :skipped ->
        Mix.shell().info("SDE data is already current")

      {:error, reason} ->
        Mix.raise("SDE sync failed: #{inspect(reason)}")
    end
  end
end

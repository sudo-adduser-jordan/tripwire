defmodule Ztripwire.Systems.Gates do
  use GenServer

  alias Ztripwire.Log

  @table __MODULE__
  @sde_file ~c"mapStargates.jsonl"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def neighbors(solar_system_id) when is_integer(solar_system_id) do
    if table?() do
      @table
      |> :ets.lookup(solar_system_id)
      |> Enum.map(fn {_id, neighbor} -> neighbor end)
      |> Enum.uniq()
      |> Enum.sort()
    else
      []
    end
  end

  def neighbors(_solar_system_id), do: []

  def put_stargates(links) when is_list(links) do
    GenServer.call(__MODULE__, {:put_stargates, links})
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  def loaded? do
    table?() and :ets.info(@table, :size) > 0
  end

  @impl true
  def init(opts) do
    path = Keyword.get(opts, :path, configured_path())
    :ets.new(@table, [:named_table, :bag, :protected, read_concurrency: true])
    load(path)
    {:ok, %{path: path}}
  end

  @impl true
  def handle_call({:put_stargates, links}, _from, state) do
    :ets.delete_all_objects(@table)
    insert_links(links)
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  defp insert_links(links) do
    rows =
      Enum.flat_map(links, fn
        {from, to} when is_integer(from) and is_integer(to) -> [{from, to}, {to, from}]
        _ -> []
      end)

    :ets.insert(@table, rows)
  end

  defp configured_path do
    :ztripwire
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:path)
  end

  defp load(nil), do: :ok

  defp load(path) do
    with {:ok, data} <- read(path) do
      links = decode(data)
      insert_links(links)
      Log.emit(:info, %{event: "gate_data_loaded", links: length(links)})
    else
      _ -> :ok
    end
  end

  defp read(path) when is_binary(path) do
    cond do
      not File.exists?(path) -> :error
      String.ends_with?(path, ".zip") -> unzip(path)
      true -> File.read(path)
    end
  end

  defp read(_path), do: :error

  defp unzip(path) do
    case :zip.unzip(String.to_charlist(path), [:memory, {:file_list, [@sde_file]}]) do
      {:ok, [{_name, data}]} -> {:ok, data}
      _ -> :error
    end
  end

  defp decode(data) when is_binary(data) do
    data
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case Jason.decode(line) do
        {:ok, %{"solarSystemID" => from, "destination" => %{"solarSystemID" => to}}}
        when is_integer(from) and is_integer(to) ->
          [{from, to}]

        _ ->
          []
      end
    end)
  end

  defp table?, do: :ets.whereis(@table) != :undefined
end

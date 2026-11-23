defmodule Tripwire.Systems.Catalog do
  use GenServer

  alias Tripwire.Log

  @table __MODULE__
  @sde_file ~c"mapSolarSystems.jsonl"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def search(query, limit \\ 8)

  def search(query, limit) when is_binary(query) do
    q = query |> String.trim() |> String.downcase()

    if q == "" do
      []
    else
      @table
      |> rows()
      |> Enum.filter(fn {_id, name, _security} ->
        String.contains?(String.downcase(name), q)
      end)
      |> Enum.sort_by(fn {id, name, _security} ->
        lowered = String.downcase(name)
        {if(String.starts_with?(lowered, q), do: 0, else: 1), lowered, id}
      end)
      |> Enum.take(limit)
      |> Enum.map(fn {id, name, security} ->
        %{solar_system_id: id, name: name, security: security}
      end)
    end
  end

  def search(_query, _limit), do: []

  def find(name) when is_binary(name) do
    q = name |> String.trim() |> String.downcase()

    if q == "" do
      nil
    else
      @table
      |> rows()
      |> Enum.find_value(fn {id, sys_name, security} ->
        if String.downcase(sys_name) == q do
          %{solar_system_id: id, name: sys_name, security: security}
        end
      end)
    end
  end

  def find(_name), do: nil

  def get(solar_system_id) when is_integer(solar_system_id) do
    if table?() do
      case :ets.lookup(@table, solar_system_id) do
        [{^solar_system_id, name, security}] ->
          %{solar_system_id: solar_system_id, name: name, security: security}

        [] ->
          nil
      end
    end
  end

  def get(_solar_system_id), do: nil

  def put_systems(entries) when is_list(entries) do
    GenServer.call(__MODULE__, {:put_systems, entries})
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
    :ets.new(@table, [:named_table, :set, :protected, read_concurrency: true])
    load(path)
    {:ok, %{path: path}}
  end

  @impl true
  def handle_call({:put_systems, entries}, _from, state) do
    :ets.delete_all_objects(@table)
    :ets.insert(@table, Enum.map(entries, &row/1))
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  defp row(entry) do
    {Map.fetch!(entry, :solar_system_id), Map.fetch!(entry, :name), Map.get(entry, :security)}
  end

  defp configured_path do
    :tripwire
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:path)
  end

  defp load(nil), do: :ok

  defp load(path) do
    with {:ok, data} <- read(path) do
      systems = decode(data)
      :ets.insert(@table, systems)
      Log.emit(:info, %{event: "system_catalog_loaded", systems: length(systems)})
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
        {:ok, %{"_key" => id, "name" => %{"en" => name}, "securityStatus" => security}}
        when is_integer(id) ->
          [{id, name, security}]

        _ ->
          []
      end
    end)
  end

  defp rows(table) do
    if table?(table), do: :ets.tab2list(table), else: []
  end

  defp table?, do: table?(@table)

  defp table?(table), do: :ets.whereis(table) != :undefined
end

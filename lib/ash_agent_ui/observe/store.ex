defmodule AshAgentUi.Observe.Store do
  @moduledoc false
  use GenServer

  alias AshAgentUi.Observe.Run

  @default_max_runs 200

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def list_runs(opts \\ []) do
    GenServer.call(__MODULE__, {:list_runs, opts})
  end

  def fetch_run(id) do
    GenServer.call(__MODULE__, {:fetch_run, id})
  end

  def start_run(attrs) do
    GenServer.call(__MODULE__, {:start_run, attrs})
  end

  def update_run(id, attrs) do
    GenServer.call(__MODULE__, {:update_run, id, attrs})
  end

  def append_event(id, event) do
    GenServer.call(__MODULE__, {:append_event, id, event})
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @impl true
  def init(opts) do
    max_runs = Keyword.get(opts, :max_runs, @default_max_runs)

    table =
      :ets.new(Keyword.get(opts, :table, __MODULE__), [:set, :protected, read_concurrency: true])

    {:ok, %{table: table, max_runs: max_runs, ids: []}}
  end

  @impl true
  def handle_call({:list_runs, opts}, _from, state) do
    limit = opts[:limit] || state.max_runs

    runs =
      state.ids
      |> Enum.take(limit)
      |> Enum.map(&lookup_run(state.table, &1))
      |> Enum.reject(&is_nil/1)

    {:reply, {:ok, runs}, state}
  end

  def handle_call({:fetch_run, id}, _from, state) do
    case lookup_run(state.table, id) do
      nil -> {:reply, {:error, :not_found}, state}
      run -> {:reply, {:ok, run}, state}
    end
  end

  def handle_call({:start_run, attrs}, _from, state) do
    run = build_run(attrs)
    state = upsert_run(state, run, true)
    {:reply, {:ok, run}, state}
  end

  def handle_call({:update_run, id, attrs}, _from, state) do
    case lookup_run(state.table, id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      run ->
        updated = apply_attrs(run, attrs)
        state = upsert_run(state, updated, false)
        {:reply, {:ok, updated}, state}
    end
  end

  def handle_call({:append_event, id, event}, _from, state) do
    case lookup_run(state.table, id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      run ->
        normalized = normalize_event(event)
        updated = %Run{run | events: run.events ++ [normalized]}
        state = upsert_run(state, updated, false)
        {:reply, {:ok, updated}, state}
    end
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.table)
    {:reply, :ok, %{state | ids: []}}
  end

  defp lookup_run(table, id) do
    case :ets.lookup(table, id) do
      [{^id, run}] -> run
      _ -> nil
    end
  end

  defp build_run(attrs) do
    attrs = Map.new(attrs)

    id = Map.get_lazy(attrs, :id, fn -> Integer.to_string(System.unique_integer([:positive])) end)
    started_at = Map.get(attrs, :started_at, DateTime.utc_now())
    inserted_at = Map.get(attrs, :inserted_at, started_at)

    defaults = %{
      id: id,
      type: Map.get(attrs, :type, :call),
      status: Map.get(attrs, :status, :running),
      started_at: started_at,
      inserted_at: inserted_at,
      agent: Map.get(attrs, :agent),
      provider: Map.get(attrs, :provider),
      profile: Map.get(attrs, :profile),
      client: Map.get(attrs, :client),
      events: Map.get(attrs, :events, [])
    }

    struct!(Run, Map.merge(attrs, defaults))
  end

  defp apply_attrs(run, attrs) do
    attrs = Map.new(attrs)

    attrs =
      if Map.has_key?(attrs, :events) do
        Map.update(attrs, :events, run.events, fn events -> run.events ++ List.wrap(events) end)
      else
        attrs
      end

    struct(run, attrs)
  end

  defp normalize_event(event) do
    event = Map.new(event)
    timestamp = Map.get(event, :timestamp, DateTime.utc_now())

    event
    |> Map.put_new(:id, "evt-" <> Integer.to_string(System.unique_integer([:positive])))
    |> Map.put(:timestamp, timestamp)
    |> Map.put(:metadata, ensure_map(Map.get(event, :metadata, %{})))
    |> Map.put(:measurements, ensure_map(Map.get(event, :measurements, %{})))
  end

  defp upsert_run(state, %Run{} = run, move_to_front) do
    :ets.insert(state.table, {run.id, run})

    ids =
      if move_to_front do
        [run.id | Enum.reject(state.ids, &(&1 == run.id))]
      else
        state.ids
      end

    {ids, dropped} = trim(ids, state.max_runs)
    Enum.each(dropped, &:ets.delete(state.table, &1))

    %{state | ids: ids}
  end

  defp trim(ids, max) when length(ids) > max do
    {kept, dropped} = Enum.split(ids, max)
    {kept, dropped}
  end

  defp trim(ids, _max), do: {ids, []}

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_), do: %{}
end

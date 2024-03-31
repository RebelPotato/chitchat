defmodule ChitChat.Space do
  @moduledoc """
  This process is a claimspace, a pubsub server for claims.

  A card daemon can subscribe to a pattern. Whenever the set of matched claims changes, it is sent to this daemon.
  This allows the daemon to choose what to do with these claims.

  A daemon can also publish claims, match a pattern, or remove all its claims from the space.
  """
  use GenServer

  @type space :: atom() | pid() | {atom(), any()} | {:via, atom(), any()}
  @type pattern :: :ets.match_pattern()

  @doc """
  Subscribe self to `space` using `pattern`. Returns the set of matched claims.

  When this set changes (for example, when a new claim arrives),
   a copy of the new set will be sent to self.

  Message format: `{:claim, $Set}`
  """
  @spec subscribe(space(), pattern()) :: [tuple()]
  def subscribe(space, pattern) do
    GenServer.call(space, {:subscribe, self(), pattern})
  end

  @doc """
  Find all claims that match `pattern`.
  """
  @spec match(space(), pattern()) :: [tuple()]
  def match(space, pattern) do
    GenServer.call(space, {:match, pattern})
  end

  @doc """
  Publish a claim as self. All claims published this way will be removed when self is down.
  """
  @spec publish(space(), [tuple()] | tuple()) :: :ok
  def publish(space, claim) do
    GenServer.call(space, {:publish, self(), claim})
  end

  @doc """
  Starts the claimspace with the given options.

  `:name` is always required.
  """
  def start_link(opts) do
    space = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, space, opts)
  end

  @impl true
  def init(store) do
    claims = :ets.new(store, [:bag, read_concurrency: true])
    monitoring = MapSet.new()
    patterns = %{}
    {:ok, {claims, monitoring, patterns}}
  end

  @impl true
  def handle_call({:subscribe, daemon, pattern}, _from, {claims, monitoring, patterns}) do
    monitoring = monitor_new(monitoring, daemon)
    current_patterns = case Map.get(patterns, daemon) do
        nil -> []
        list -> list
      end
    patterns = Map.put(patterns, daemon, [pattern | current_patterns])
    {:reply, match_pattern(claims, pattern), {claims, monitoring, patterns}}
  end

  @impl true
  def handle_call({:match, pattern}, _from, {claims, monitoring, patterns}) do
    {:reply, match_pattern(claims, pattern), {claims, monitoring, patterns}}
  end

  @impl true
  def handle_call({:publish, daemon, claim}, _from, {claims, monitoring, patterns}) do
    monitoring = monitor_new(monitoring, daemon)
    :ets.insert(claims, {daemon, claim})

    for {pid, pattern_list} <- get_matching_pattern(patterns, claim),
        pattern <- pattern_list do
      new_list = match_pattern(claims, pattern)
      send(pid, {:claims, new_list})
    end

    {:reply, :ok, {claims, monitoring, patterns}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, daemon, _reason}, {claims, monitoring, patterns}) do
    IO.puts("Dead daemon acknowledged")
    deleted_claims = :ets.lookup(claims, daemon) |> Enum.map(fn {_daemon, statement} -> statement end)
    :ets.delete(claims, daemon)
    monitoring = MapSet.delete(monitoring, daemon)
    patterns = Map.delete(patterns, daemon)

    for {pid, pattern_list} <- get_matching_pattern(patterns, deleted_claims),
        pattern <- pattern_list do
      new_list = match_pattern(claims, pattern)
      send(pid, {:claims, new_list})
    end

    {:noreply, {claims, monitoring, patterns}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Returns all claims in table that match pattern.
  # Claims are stored as {daemon.info, claim} inside ets, this function removes it.
  @spec match_pattern(:ets.table(), pattern()) :: [tuple()]
  defp match_pattern(table, pattern) do
    :ets.match_object(table, {:_, pattern})
    |> Enum.map(fn {_daemon, statement} -> statement end)
    |> Enum.uniq()
  end

  @spec get_matching_pattern(map(), [tuple()] | tuple()) :: [{pid(), [pattern()]}]
  defp get_matching_pattern(map, statement) do
    tmp = :ets.new(:temporary, [])
    :ets.insert(tmp, statement)
    for {daemon, pats} <- map do
      new_pats = for pat <- pats, length(:ets.match_object(tmp, pat)) > 0, do: pat
      {daemon, new_pats}
    end
  end

  @spec monitor_new(MapSet.t(), any()) :: MapSet.t()
  defp monitor_new(monitoring, pid) do
    if MapSet.member?(monitoring, pid) do monitoring else
      Process.monitor(pid)
      MapSet.put(monitoring, pid)
    end
  end
end

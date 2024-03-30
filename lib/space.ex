defmodule ChitChat.Space do
  @moduledoc """
  This process stores the active claims, and runs or stops card processes when claims change.

  Each statement is stored with its owning card's name (module name atom) as key.
  """
  use GenServer

  @doc """
  Create a card with this claimspace as parent.
  """
  def create_card(space, card_module) do
    :ok = GenServer.call(space, {:create_card, card_module})
  end

  @doc """
  Create a statement on this claimspace.
  """
  def create_statement(space, statement) do
    :ok = GenServer.call(space, {:create_statement, statement})
  end

  @spec match_all(atom() | pid() | {atom(), any()} | {:via, atom(), any()}, any()) :: any()
  @doc """
  Returns all statements that match the pattern.
  """
  def match_all(space, pattern) do
    GenServer.call(space, {:match, pattern})
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
    statements = :ets.new(store, [:named_table, :bag, read_concurrency: true])
    info = %{}
    {:ok, {statements, info}}
  end

  @impl true
  def handle_call({:create_card, card}, _from, {statements, info}) do
    {:ok, pid} = DynamicSupervisor.start_child(ChitChat.Cards, Task.Supervisor)
    ref = Process.monitor(pid)
    snippets = card.snippets()
    info = Map.put(info, card, %{supervisor: ref, snippets: snippets})

    Task.Supervisor.async(pid, card, :start_card, [self()])
    {:reply, :ok, {statements, info}}
  end

  @impl true
  def handle_call({:create_statement, statement}, _from, {statements, info}) do
    :ets.insert(statements, statement)
    {:reply, :ok, {statements, info}}
  end

  @impl true
  def handle_call({:match, pattern}, _from, {statements, info}) do
    results = :ets.match_object(statements, pattern)
    {:reply, results, {statements, info}}
  end

  # @impl true
  # def handle_info({:DOWN, ref, :process, _pid, _reason}, {statements}) do
  #   # 6. Delete from the ETS table instead of the map
  #   {name, refs} = Map.pop(refs, ref)
  #   :ets.delete(info, name)
  #   {:noreply, {statements}}
  # end

  # @impl true
  # def handle_info(_msg, state) do
  #   {:noreply, state}
  # end
end

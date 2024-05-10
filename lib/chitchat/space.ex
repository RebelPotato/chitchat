defmodule ChitChat.Space do
  @moduledoc """
  This process is a claimspace, a pubsub server for claims.

  A card daemon can subscribe using a pattern. Whenever the set of matched claims changes, it is sent to this daemon.
  This allows it to choose what to do with these claims.

  A daemon can also publish claims, match a pattern or modify an existing claim.

  All its claims are removed from the space automatically when it dies.
  """
  alias ChitChat.Claim
  use GenServer
  @type claim :: tuple()
  @type pattern :: [term()]
  @type client :: {pattern, module, atom} | {pattern, (-> any())}
  # client
  @doc """
  Assert a claim. Automatically retracted when the client dies.
  """
  @spec assert(pid, claim) :: :ok
  def assert(space, claim) do
    GenServer.call(space, {:assert, self(), claim})
  end

  @doc """
  Register a task to be run on a certain pattern. The matched environment will be passed to the function as args.
  """
  @spec register(pid, pattern, module, atom) :: :ok
  def register(space, pattern, module, function_name) do
    GenServer.call(space, {:register, self(), pattern, module, function_name})
  end

  @doc """
  Register a simple task without arguments to be run on a certain pattern.
  """
  @spec register(pid, pattern, (-> any())) :: :ok
  def register(space, pattern, function) do
    GenServer.call(space, {:register, self(), pattern, function})
  end

  # server
  def init(_) do
    {:ok,
     %{
       # client to the pattern it watches
       watches: %{},
       # pid to the client that runs it
       runs: %{},
       # claim_ref to the pid that made it
       claims: %{},
       # claim_ref to its content
       refs: %{}
     }}
  end

  # def handle_call(
  #       {:assert, client_pid, claim},
  #       _from,
  #       %{watches: watches, runs: runs, refs: refs, claims: claims}
  #     ) do
  #   claim = Claim.transform(claim)
  #   # TODO one pattern can match multiple claims. Then what?
  #   new_runs =
  #     for {client, pattern} <- watches, {:ok, env} = Claim.match(pattern, claim), into: runs do
  #       pid = start_client(client, env)
  #       {pid, client}
  #     end

  #   ref = make_ref()

  #   {:reply, :ok,
  #    %{
  #      watches: watches,
  #      runs: new_runs,
  #      refs: Map.put(refs, ref, claim),
  #      claims: Map.put(claims, ref, client_pid)
  #    }}
  # end

  # def handle_call(
  #       {:register, _pid, pattern, module, function_name},
  #       _from,
  #       %{watches: watches} = state
  #     ) do
  #   client = {pattern, module, function_name}
  #   new_watches = Map.put(watches, client, pattern)
  #   {:reply, :ok, %{state | watches: new_watches}}
  # end

  # def handle_call(
  #       {:register, _pid, pattern, function},
  #       _from,
  #       %{watches: watches} = state
  #     ) do
  #   client = {pattern, function}
  #   new_watches = Map.put(watches, client, pattern)
  #   {:reply, :ok, %{state | watches: new_watches}}
  # end

  # def handle_info(
  #       {:DOWN, _ref, :process, client_pid, _reason},
  #       %{
  #         watches: watches,
  #         runs: runs,
  #         refs: refs,
  #         claims: claims
  #       } = state
  #     ) do
  #   retracted_claims = claims |> Map.keys() |> Enum.filter(&(Map.get(runs, &1) == client_pid))
  #   new_watches = Map.delete(watches, client_pid)
  #   {:noreply, %{state | watches: new_watches}}
  # end

  # @spec start_client(client, map) :: pid
  # defp start_client({pattern, module, function_name}, env) do
  #   # start a client as a Task under the space's supervisor
  #   self()
  # end

  # defp start_client({pattern, function}, env) do
  #   # start a client as a Task under the space's supervisor
  #   self()
  # end
end

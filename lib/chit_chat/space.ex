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
  @type pattern :: [pterm]
  @type claim :: [atomic | claim]
  @type pterm :: [atomic | variable | pterm]
  @type shape :: [atomic | :_ | shape]

  @type variable :: Claim.Var.t() | :_
  @type atomic :: number | atom | binary

  @type env :: %{} | %{Claim.Var.t() => claim}

  @type space :: pid
  # client
  @doc """
  Assert a claim. Automatically retracted when the client dies.
  """
  @spec assert(space, claim) :: :ok
  def assert(space, claim) do
    GenServer.call(space, {:assert, self(), claim})
  end

  @doc """
  Register a task to be run on a certain pattern. The matched environment will be passed to the function as args.

  Returns a reference that can be used to unregister the task.
  """
  @spec register(space, pattern, module, atom) :: reference
  def register(space, pattern, module, function_name) do
    GenServer.call(space, {:register, self(), pattern, {module, function_name}})
  end

  @doc """
  Register a simple task without arguments to be run on a certain pattern.
  """
  @spec register(space, pattern, (-> any())) :: reference
  def register(space, pattern, function) do
    GenServer.call(space, {:register, self(), pattern, function})
  end

  @spec unregister(space, reference) :: :ok
  def unregister(space, ref) do
    GenServer.call(space, {:unregister, self(), ref})
  end

  # server
  @type claim_shapes :: %{shape => [claim]}
  @type pattern_shapes :: %{shape => [reference]}
  @type registered_function :: {module, atom} | (-> any())
  @type client_data :: %{
          reference => %{
            pattern: pattern,
            function: registered_function,
            active: [pid]
          }
        }

  @type clients :: %{pid => %{type: reference, claims: [claim], task: Task.t()}}
  @type state :: %{
          claim_shapes: claim_shapes,
          pattern_shapes: pattern_shapes,
          client_data: client_data,
          active_clients: clients
        }

  @spec init(any) :: {:ok, state}
  def init(_) do
    {:ok,
     %{
       # quick lookup for all claims with a certain shape
       claim_shapes: %{},
       # quick lookup for all clients that listen to a certain shape
       pattern_shapes: %{},
       # data for spawning clients
       client_data: %{},
       # currently active clients
       active_clients: %{}
     }}
  end

  def handle_call({:assert, client_pid, new_claim}, _from, state) do
    state = just_assert(client_pid, new_claim, state)
    {:reply, :ok, state}
  end

  def handle_call({:register, _pid, pattern, func}, _from, state) do
    {state, ref} = just_register(pattern, func, state)
    {:reply, ref, state}
  end

  def handle_call({:unregister, _pid, ref}, _from, state) do
    state = just_unregister(ref, state)
    {:reply, :ok, state}
  end

  def handle_info({:DOWN, _ref, :process, client_pid, _reason}, state) do
    state = just_remove(client_pid, state)
    {:noreply, state}
  end

  @spec just_assert(pid, claim, state) :: state
  defp just_assert(
         client_pid,
         new_claim,
         %{
           claim_shapes: claim_shapes,
           pattern_shapes: pattern_shapes,
           client_data: client_data,
           active_clients: active_clients
         } = state
       ) do
    shape = Claim.to_shape(new_claim)

    matches =
      case Map.fetch(pattern_shapes, shape) do
        {:ok, potential_refs} ->
          for ref <- potential_refs,
              {:ok, %{pattern: pattern}} = Map.fetch(client_data, ref),
              pterm <- pattern,
              pshape = Claim.to_shape(pterm),
              {:ok, claims} = Map.fetch(claim_shapes, pshape),
              claims = if(shape === pshape, do: [new_claim | claims], else: claims),
              reduce: [{false, %{}}] do
            acc ->
              for {status, env} <- acc,
                  claim <- claims,
                  {:ok, new_env} = Claim.match(env, claim, pterm),
                  do: {status || claim === new_claim, new_env, ref}
          end

        _ ->
          []
      end

    envs = for {status, env, ref} <- matches, status, do: {env, ref}

    new_claim_shapes = Map.update(claim_shapes, shape, [new_claim], &[new_claim | &1])

    # new_clients =
    #   Map.update!(
    #     active_clients,
    #     client_pid,
    #     &Map.update!(&1, :claims, fn list -> [new_claim | list] end)
    #   )

    # new_clients =
    #   for {env, ref} <- envs,
    #       {:ok, %{function: func}} = Map.fetch(client_data, ref),
    #       task = start_client(env, func),
    #       reduce: new_clients do
    #     acc -> Map.put(acc, task.pid, %{type: ref, claims: [], task: task})
    #   end

    # %{state | claim_shapes: new_claim_shapes, active_clients: new_clients}
  end

  @spec just_register(pattern, registered_function, state) :: {state, reference}
  defp just_register(pattern, func, %{
         claim_shapes: claim_shapes,
         pattern_shapes: pattern_shapes,
         client_data: client_data,
         active_clients: active_clients
       }) do
    envs =
      for pterm <- pattern,
          shape = Claim.to_shape(pterm),
          {:ok, claims} = Map.fetch(claim_shapes, shape),
          reduce: [%{}] do
        acc ->
          for env <- acc,
              claim <- claims,
              {:ok, new_env} = Claim.match(env, claim, pterm),
              do: new_env
      end

    ref = make_ref()

    new_pattern_shapes =
      for pterm <- pattern, shape = Claim.to_shape(pterm), reduce: pattern_shapes do
        acc -> Map.update(acc, shape, [ref], &[ref | &1])
      end

    started_tasks = for env <- envs, do: start_client(env, func)

    new_client_data =
      Map.put(client_data, ref, %{
        pattern: pattern,
        function: func,
        active: Enum.map(started_tasks, & &1.pid)
      })

    new_clients =
      for task <- started_tasks, reduce: active_clients do
        acc -> Map.put(acc, task.pid, %{type: ref, claims: [], task: task})
      end

    state = %{
      claim_shapes: claim_shapes,
      pattern_shapes: new_pattern_shapes,
      client_data: new_client_data,
      active_clients: new_clients
    }

    {state, ref}
  end

  @spec just_unregister(reference, state) :: state
  defp just_unregister(
         ref,
         %{
           claim_shapes: claim_shapes,
           pattern_shapes: pattern_shapes,
           client_data: client_data,
           active_clients: active_clients
         } = state
       ) do
    IO.warn("not implemented")
    state
  end

  # after pid dies, remove all traces of it from state
  # and shutdown all tasks that use its claims
  @spec just_remove(pid, state) :: state
  defp just_remove(
         client_pid,
         %{
           claim_shapes: claim_shapes,
           pattern_shapes: pattern_shapes,
           client_data: client_data,
           active_clients: active_clients
         } = state
       ) do
    %{type: type, claims: deleted_claims} = Map.fetch!(active_clients, client_pid)
    %{pattern: deleted_pattern} = Map.fetch!(client_data, type)

    new_claim_shapes =
      for claim <- deleted_claims,
          shape = Claim.to_shape(claim),
          reduce: claim_shapes do
        acc -> remove_from(acc, shape, claim)
      end

    new_pattern_shapes =
      for pterm <- deleted_pattern, shape = Claim.to_shape(pterm), reduce: pattern_shapes do
        acc -> remove_from(acc, shape, type)
      end

    new_client_data =
      Map.update!(client_data, type, fn client ->
        Map.update!(client, :active, &List.delete(&1, client_pid))
      end)

    new_clients = Map.delete(active_clients, client_pid)

    %{
      claim_shapes: new_claim_shapes,
      pattern_shapes: new_pattern_shapes,
      client_data: new_client_data,
      active_clients: new_clients
    }
  end

  @spec remove_from(%{shape => [any]}, shape, any) :: %{shape => [any]}
  defp remove_from(shape_map, shape, value) do
    case Map.fetch(shape_map, shape) do
      {:ok, list} ->
        Map.put(shape_map, shape, List.delete(list, value))

      _ ->
        shape_map
    end
  end

  @spec end_client(Task.t()) :: :ok
  def end_client(task) do
    Task.shutdown(task)
    :ok
  end

  @spec start_client((-> any())) :: Task.t()
  def start_client(func), do: start_client(func, %{})

  @spec start_client(registered_function, env) :: Task.t()
  def start_client({module, function_name}, env) do
    # start a client as a Task under the space's supervisor
    task =
      Task.Supervisor.async_nolink(
        ChitChat.Space.TaskSupervisor,
        module,
        function_name,
        [env]
      )

    Process.monitor(task.pid)
    task
  end

  def start_client(func, _env) do
    # start a client as a Task under the space's supervisor
    # TODO: implement this
    task =
      Task.Supervisor.async_nolink(
        ChitChat.Space.TaskSupervisor,
        func
      )

    Process.monitor(task.pid)
    task
  end
end

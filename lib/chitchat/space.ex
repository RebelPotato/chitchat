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
    GenServer.call(space, {:register, self(), pattern, {module, function_name}})
  end

  @doc """
  Register a simple task without arguments to be run on a certain pattern.
  """
  @spec register(pid, pattern, (-> any())) :: :ok
  def register(space, pattern, function) do
    GenServer.call(space, {:register, self(), pattern, function})
  end

  # server
  @type claim_shapes :: %{shape => [claim]}
  @type pattern_shapes :: %{shape => [reference]}
  @type registered_function :: {module, atom} | (-> any())
  @type client_data :: %{
          reference => %{
            pattern: pattern,
            function: registered_function,
            task: Task.t()
          }
        }

  @type clients :: %{pid => %{type: reference, claims: [claim]}}
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
    state = just_register(pattern, func, state)
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

    new_clients =
      Map.update!(
        active_clients,
        client_pid,
        &Map.update!(&1, :claims, fn list -> [new_claim | list] end)
      )

    new_clients =
      for {env, ref} <- envs,
          {:ok, %{function: func}} = Map.fetch(client_data, ref),
          task = start_client(env, func),
          reduce: new_clients do
        acc -> Map.put(acc, task.pid, %{type: ref, claims: [], task: task})
      end

    %{state | claim_shapes: new_claim_shapes, active_clients: new_clients}
  end

  @spec just_register(pattern, registered_function, state) :: state
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

    new_client_data = Map.put(client_data, ref, %{pattern: pattern, function: func})

    new_clients =
      for env <- envs,
          task = start_client(env, func),
          reduce: active_clients do
        acc -> Map.put(acc, task.pid, %{type: ref, claims: [], task: task})
      end

    %{
      claim_shapes: claim_shapes,
      pattern_shapes: new_pattern_shapes,
      client_data: new_client_data,
      active_clients: new_clients
    }
  end

  @spec just_remove(pid, state) :: state
  def just_remove(
        client_pid,
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

  @spec end_client(Task.t()) :: :ok
  def end_client(task) do
    Task.shutdown(task)
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

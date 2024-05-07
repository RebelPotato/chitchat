defmodule ChitChat.Space do
  @moduledoc """
  This process is a claimspace, a pubsub server for claims.

  A card daemon can subscribe to a pattern. Whenever the set of matched claims changes, it is sent to this daemon.
  This allows the daemon to choose what to do with these claims.

  A daemon can also publish claims, match a pattern or modify an existing claim.

  All its claims are removed from the space automatically when it dies.
  """
  # use GenServer

  @doc """
  Matches a claim against a stored pattern. See `ChitChat.Space.match/2` for more information.
  TODO: perhaps put this function inside a separate module?
  """
  @spec match([term], [term]) :: {:ok, map} | {:error, {term, {term, term}, {term, term}}}
  def match(lhs, rhs) do
    match(lhs, rhs, %{})
  end

  @doc """
  Matches a claim against a stored pattern.
  Assumes that all tuples in the claim and pattern have been transformed into lists.

  Returns `{:ok, new_env}` if the claim matches the pattern, where new_env is the environment extended with the new bindings.

  Returns `{:error, {:length_mismatch, lhs, rhs} | {:variable_mismatch, var, new_value, old_value} | {:value_mismatch, value1, value2}}` if the claim does not match the pattern.
  """
  @spec match([term], [term], map) ::
          {:ok, map}
          | {:error,
             {:length_mismatch, [term], [term]}
             | {:variable_mismatch, term, term, term}
             | {:value_mismatch, term, term}}
  def match([{:var, lvar} | ls], [r | rs], env) do
    case match(ls, rs, env) do
      {:ok, env} ->
        if(Map.has_key?(env, lvar)) do
          if(env[lvar] == r) do
            {:ok, env}
          else
            {:error, {:variable_mismatch, lvar, r, env[lvar]}}
          end
        else
          {:ok, Map.put(env, lvar, r)}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def match([l | ls], [r | rs], env) when is_list(l) and is_list(r) do
    case match(l, r, env) do
      {:ok, env} -> match(ls, rs, env)
      {:error, reason} -> {:error, reason}
    end
  end

  def match([l | ls], [r | rs], env) do
    if(l == r) do
      match(ls, rs, env)
    else
      {:error, {:value_mismatch, l, r}}
    end
  end

  def match([], [], env) do
    {:ok, env}
  end

  def match(lhs, rhs, _) do
    # one of lhs and rhs is the empty list, but not both
    {:error, {:length_mismatch, lhs, rhs}}
  end
end

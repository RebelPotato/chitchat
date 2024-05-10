defmodule ChitChat.Claim do
  @moduledoc """
  Utility functions for operating on claims.
  """
  defmodule Var do
    @doc """
    A variable in a claim.
    """
    alias Var

    @type t :: %Var{var: atom(), context: atom(), module: atom()}
    defstruct [:var, :context, :module]

    @spec new({atom(), atom(), atom()}) :: ChitChat.Claim.Var.t()
    def new({var, context, module}) do
      %Var{var: var, context: context, module: module}
    end
  end

  defmodule And do
    @doc """
    A conjunction of claims.
    """
    alias ChitChat.Claim
    alias And

    @type t(claim_type) :: %And{list: [claim_type]}
    defstruct [:list]

    @spec new([Claim.cterm()]) :: And.t(Claim.cterm())
    def new(list) do
      %And{list: list}
    end
  end

  @type pattern_ast :: {:{}, [], [pattern_ast()]} | {:and, keyword(), [pattern_ast()]} | cterm()

  @type pattern :: And.t(cterm) | cterm
  @type cterm :: atomic | variable | [cterm]
  @type variable :: Var.t() | :_
  # matchable terms
  @type atomic :: number | atom | binary

  @doc """
  Transforms the syntax tree of a pattern into a piece of pattern data.
  """
  @spec ast_to_pattern(pattern_ast) :: pattern
  def ast_to_pattern({:{}, [], list}) do
    list |> Enum.map(&ast_to_pattern/1)
  end

  def ast_to_pattern({:and, _, list}) do
    transformed_list = list |> Enum.map(&ast_to_pattern/1)

    new_list =
      case transformed_list do
        [%And{list: list}, y] -> [y | list]
        [x, y] -> [x, y]
      end

    And.new(new_list)
  end

  def ast_to_pattern({:_, _, _}) do
    :_
  end

  def ast_to_pattern({var, context, module}) when is_atom(var) do
    Var.new({var, context, module})
  end

  def ast_to_pattern(x) when is_list(x), do: x |> Enum.map(&ast_to_pattern/1)
  def ast_to_pattern(x) when is_tuple(x), do: x |> Tuple.to_list() |> ast_to_pattern()
  def ast_to_pattern(x), do: x

  @type env :: %{} | %{Var.t => term}

  @spec walk(term, env) :: term
  def walk(cterm, env) do
    case Map.fetch(env, cterm) do
      {:ok, val} -> walk(val, env)
      :error -> cterm
    end
  end

  @spec simplify(pattern, env) :: pattern
  def simplify(cterm, env) do
    case walk(cterm, env) do
      [h | t] -> [simplify(h, env) | simplify(t, env)]
      cterm -> cterm
    end
  end

  @spec do_unify(env, cterm, cterm) :: {:ok, env} | {:error, env, cterm, cterm}
  def unify(env, term1, term2) do
    do_unify(env, simplify(term1, env), simplify(term2, env))
  end

  defp do_unify(env, :_, _) do
    {:ok, env}
  end

  defp do_unify(env, _, :_) do
    {:ok, env}
  end

  defp do_unify(env, term1, term2) when term1 == term2 do
    {:ok, env}
  end

  defp do_unify(env, term1, %Var{} = var) do
    extend(env, var, term1)
  end

  defp do_unify(env, %Var{} = var, term2) do
    extend(env, var, term2)
  end

  defp do_unify(env, [h1 | t1], [h2 | t2]) do
    with {:ok, env} <- do_unify(env, h1, h2) do
      do_unify(env, t1, t2)
    end
  end

  defp do_unify(env, term1, term2) do
    {:error, env, term1, term2}
  end

  @spec extend(env, Var.t, cterm) :: {:ok, env}
  defp extend(env, var, cterm) do
    {:ok, Map.put(env, var, cterm)}
  end
end
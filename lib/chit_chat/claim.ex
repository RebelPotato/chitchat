defmodule ChitChat.Claim do
  @moduledoc """
  Utility functions for operating on patterns and claims.

  A pattern is a conjunction or disjunction of claims. Claims can contain variables.
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

  @type pattern_ast :: {:{}, [], [pattern_ast]} | [pattern_ast] | {atom, keyword, atom} | atomic

  @type pattern :: [pterm]
  @type claim :: [atomic | claim]
  @type pterm :: [atomic | variable | pterm]
  @type shape :: [atomic | :_ | shape]
  @type variable :: Var.t() | :_
  # matchable terms
  @type atomic :: number | atom | binary
  @type env :: %{} | %{Var.t() => claim}

  @doc """
  Transforms the syntax tree of a pattern into a piece of pattern data.
  """
  @spec ast_to_pattern(pattern_ast) :: pattern
  def ast_to_pattern(tree) do
    case ast_to_pattern_inner(tree) do
      list when is_list(list) -> list
      x -> [x]
    end
  end

  @type prepattern :: pterm | {:and, [pterm]}
  @spec ast_to_pattern_inner(pattern_ast) :: prepattern
  def ast_to_pattern_inner({:{}, [], list}) do
    list |> Enum.map(&ast_to_pattern_inner/1)
  end

  def ast_to_pattern_inner({:_, _, _}), do: :_
  def ast_to_pattern_inner({var, context, module}) when is_atom(var),
    do: Var.new({var, context, module})

  def ast_to_pattern_inner(x) when is_list(x), do: x |> Enum.map(&ast_to_pattern_inner/1)
  def ast_to_pattern_inner(x) when is_tuple(x), do: x |> Tuple.to_list() |> Enum.map(&ast_to_pattern_inner/1)
  def ast_to_pattern_inner(x), do: x

  @doc """
  Transforms a claim into a shape.
  """
  @spec to_shape(pterm) :: shape
  def to_shape(claim), do: Enum.map(claim, &to_shape_inner/1)
  defp to_shape_inner(%Var{}), do: :_
  defp to_shape_inner(list) when is_list(list), do: Enum.map(list, &to_shape_inner/1)
  defp to_shape_inner(x), do: x

  @doc """
  Matches a claim against a pterm, adding the matched variables to the environment.
  """
  @spec match(env, claim, pterm) :: {:ok, env} | :error
  def match(env, [c | cs], [p | ps]) do
    case match(c, p, env) do
      {:ok, new_env} -> match(new_env, cs, ps)
      :error -> :error
    end
  end

  def match(env, x, %Var{} = var) do
    case Map.fetch(env, var) do
      :error -> {:ok, Map.put(env, var, x)}
      {:ok, ^x} -> {:ok, env}
      _ -> :error
    end
  end

  def match(env, _, :_), do: {:ok, env}
  def match(env, x, x), do: {:ok, env}
  def match(_, _, _), do: :error
end

defmodule ChitchatClaimTest do
  use ExUnit.Case
  import ChitChat.Claim

  test "Logic 'and' and 'or'" do
    alias ChitChat.Claim.Var
    x = Var.new({:x, :_, :_})
    y = Var.new({:y, :_, :_})
    values = all_of([
      any_of([
        equal(x, 1),
        equal(x, y)
      ]),
      any_of([
        equal(y, 2),
        equal(y, 3)
      ])
    ])
    |> show([x, y]) |> MapSet.new()
    assert values == MapSet.new([[1,3], [1,2], [2,2], [3,3]])
  end
end

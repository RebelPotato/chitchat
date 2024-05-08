defmodule ChitchatClaimTest do
  use ExUnit.Case
  alias ChitChat.Claim

  test "Matches extracts values" do
    assert {:ok, %{x: 2, y: 4}} = Claim.match([1, [{:var, :x}, 3], {:var, :y}, 5], [1, [2, 3], 4, 5])
  end

  test "Matches fails on length mismatch" do
    assert {:error, _} = Claim.match([1, [{:var, :x}, 3], {:var, :y}, 5], [1, [2, 3], 4])
  end

  test "Matches fails on variable mismatch" do
    assert {:error, _} = Claim.match([1, [{:var, :x}, 3], {:var, :y}, 5], [1, [2, 3], 4, 6])
  end

  test "Matches when values match" do
    assert {:ok, %{x: 2}} = Claim.match([1, [{:var, :x}, 3], {:var, :x}, 5], [1, [2, 3], 2, 5])
  end

  test "Matches fails on value mismatch" do
    assert {:error, _} = Claim.match([1, [{:var, :x}, 3], {:var, :x}, 5], [1, [2, 3], 4, 5])
  end

end

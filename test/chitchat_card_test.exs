defmodule ChitchatCardTest do
  alias ChitChat.Space
  alias ChitChat.HelloCard1
  use ExUnit.Case

  # setup do
  #   # supervisor = start_supervised!(ChitChat.Supervisor)
  #   # [_ | [{_, space, _, _} | _]] = Supervisor.which_children(supervisor)
  #   # %{space: space}
  # end

  # test "Add 2 hello world cards into space", %{space: space} do
  #   # Space.create_card(space, HelloCard1) # this card claims {self(), "is hello world"} on start
  #   # IO.puts("Waiting for card to start and insert statement...")
  #   # Process.sleep(2000)

  #   # # if this card runs successfully, the claimspace should have one "is hello world" statement
  #   # statements = Space.match_all(space, {:_, {:_, "is hello world"}}) |> IO.inspect()
  #   # assert length(statements) == 1

  #   # Space.create_card(space, HelloCard2) # this card wishes each card that "is hello world" to be "is painted blue"
  #   # IO.puts("Waiting for card to start and insert statement...")
  #   # Process.sleep(2000)

  #   # # if both cards run successfully, the claimspace should have one "someone wishes something" statement
  #   # statements = Space.match_all(space, {:_, {:_, "wishes", :_}}) |> IO.inspect()
  #   # assert length(statements) == 1
  # end

  # test "Add 2 hello world cards, then remove No.1", %{space: _space} do
  #   assert true
  # end

  # test "Add 2 hello world cards, then remove No.2", %{space: _space} do
  #   assert true
  # end
end

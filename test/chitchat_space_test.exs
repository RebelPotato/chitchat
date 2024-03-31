defmodule ChitchatSpaceTest do
  use ExUnit.Case

  defmodule ProxyDaemon do
    alias ChitChat.Space
    def start(space, pattern, receiver) do
      claims = Space.subscribe(space, pattern)
      send(receiver, claims)
      loop_acceptor(space, receiver)
    end

    def loop_acceptor(space, receiver) do
      receive do
        {:claim, claim_fn} ->
          Space.publish(space, claim_fn.())
        {:claims, claims} ->
          send(receiver, claims)
      end

      loop_acceptor(space, receiver)
    end
  end

  setup do
    space = start_supervised!({ChitChat.Space, name: ChitChat.Space})
    %{space: space}
  end

  test "daemon1 listens to others' claims", %{space: space} do
    spawn(ProxyDaemon, :start, [space, {:_, "is hello world"}, self()])
    assert_receive []
    daemon2 = spawn(ProxyDaemon, :loop_acceptor, [space, self()])
    send(daemon2, {:claim, fn -> {self(), "is hello world"} end})
    daemon3 = spawn(ProxyDaemon, :loop_acceptor, [space, self()])
    send(daemon3, {:claim, fn -> {self(), "is hello world"} end})
    assert_receive [{_, "is hello world"}, {_, "is hello world"}]
    Process.exit(daemon2, :kill)
    assert_receive [{_, "is hello world"}], 1000
  end
end

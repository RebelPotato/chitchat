defmodule ChitChat.HelloCard1 do
  alias ChitChat.Card
  @behaviour Card
  @name __MODULE__
  Module.register_attribute(__MODULE__, :snippet, accumulate: true)


  @impl true
  def start_card(space) do
    Card.claim(space, {@name, "is hello world"})
  end

  # @impl true
  # def handle_call(:whatever, _from, space) do
  #   Card.claim(space, {"is called", self()})
  #   {:noreply, space}
  # end

  @impl true
  def snippets do
    @snippet
  end
end

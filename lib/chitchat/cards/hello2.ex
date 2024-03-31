defmodule ChitChat.HelloCard2 do
  alias ChitChat.Card
  @behaviour Card
  @name __MODULE__
  Module.register_attribute(__MODULE__, :snippet, accumulate: true)

  @impl true
  def start_card(_space) do
  end

  def make_others_blue(space, {other, "is hello world"}) do
    Card.wish(space, @name, {other, "is painted blue"})
  end
  @snippet {{:_, "is hello world"}, @name, :make_others_blue}

  @impl true
  def snippets do
    @snippet
  end
end

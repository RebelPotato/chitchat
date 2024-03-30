defmodule ChitChat.Supervisor do
  @moduledoc """
  Supervisor for Chitchat toplevel.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {ChitChat.Space, name: ChitChat.Space},
      {DynamicSupervisor, name: ChitChat.Cards, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end

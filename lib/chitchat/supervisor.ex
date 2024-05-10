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
      {DynamicSupervisor, name: ChitChat.Space.PatternSupervisor},
      {ChitChat.Space, name: ChitChat.Space},
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end

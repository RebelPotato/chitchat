defmodule ChitChat do
  @moduledoc """
  This is the central part of chitchat.
  """
  use Application

  def start(_type, _args) do
    ChitChat.Supervisor.start_link(name: ChitChat.Supervisor)
  end
end

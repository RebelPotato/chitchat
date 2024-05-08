defmodule ChitChat.Space do
  @moduledoc """
  This process is a claimspace, a pubsub server for claims.

  A card daemon can subscribe to a pattern. Whenever the set of matched claims changes, it is sent to this daemon.
  This allows the daemon to choose what to do with these claims.

  A daemon can also publish claims, match a pattern or modify an existing claim.

  All its claims are removed from the space automatically when it dies.
  """
  # use GenServer
end

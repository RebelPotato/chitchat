defmodule ChitChat.Card do
  @moduledoc """
  This module defines the behavior for cards.
  Cards are the fundamental computational units in Chitchat.
  Each card has the activity to claim things and run snippets.

  Snippets are functions that run when certain claims are matched in the claimspace.
  They can make claims when run.

  Each card process correspond to one piece of paper.
  It is started when the paper enters the table, and terminated when it leaves.

  Several sample cards can be found in the "cards" folder and in the tests.
  """
alias ChitChat.Space

  @doc """
  When a card is started, the function `&start_card/1` is called with the claimspace's pid as parameter.
  This function can invoke claims.
  """
  @callback start_card(pid()) :: nil
  @doc """
  All snippets this card can invoke.
  """
  @callback snippets() :: [{:ets.match_pattern(), module(), atom()}]

  @doc """
  Makes the current module a card.
  """
  defmacro __using__(_opts) do
    quote do
    end
  end

  def claim(space, statement) do
  end

  def wish(space, name, statement) do
  end
end

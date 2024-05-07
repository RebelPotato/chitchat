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

end

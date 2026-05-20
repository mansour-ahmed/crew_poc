defmodule CrewPocWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint CrewPocWeb.Endpoint

      import Phoenix.ChannelTest
      import CrewPocWeb.ChannelCase
      import CrewPoc.Generator
    end
  end

  setup tags do
    CrewPoc.DataCase.setup_sandbox(tags)
    :ok
  end
end

defmodule Farmbot.System.NervesHubClient do
  @moduledoc """
  Client that decides when an update should be done.
  """
  @behaviour NervesHub.Client

  @impl NervesHub.Client
  def update_available(_), do: :apply
end

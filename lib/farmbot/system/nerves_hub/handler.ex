defmodule Farmbot.System.NervesHub.Handler do
  @moduledoc """
  Handler that decides when an update/reboot should be done.
  """

  @behaviour NervesHub.UpdateHandler

  @impl NervesHub.UpdateHandler
  def should_update?(_), do: true

  @impl NervesHub.UpdateHandler
  def should_reboot?(), do: true

  # Will never be called.
  @impl NervesHub.UpdateHandler
  def update_frequency(), do: 1

  # Will never be called.
  @impl NervesHub.UpdateHandler
  def reboot_frequency(), do: 1
end

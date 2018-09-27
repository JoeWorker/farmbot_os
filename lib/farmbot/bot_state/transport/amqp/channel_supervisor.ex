defmodule Farmbot.BotState.Transport.AMQP.ChannelSupervisor do
  @moduledoc false
  use Supervisor
  alias Farmbot.BotState.Transport.AMQP.{
    ConnectionWorker,
    LogTransport,
    BotStateTransport,
    AutoSyncTransport,
    CeleryScriptTransport,
    NervesHubTransport
  }

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([token]) do
    Process.flag(:sensitive, true)
    conn = ConnectionWorker.connection()
    jwt = Farmbot.Jwt.decode!(token)
    children = [
      {LogTransport,          [conn, jwt]},
      {BotStateTransport,     [conn, jwt]},
      {AutoSyncTransport,     [conn, jwt]},
      {CeleryScriptTransport, [conn, jwt]}
    ]
    Supervisor.init(children, [strategy: :one_for_one])
  end
end

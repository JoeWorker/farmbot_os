defmodule Farmbot.BotState.Transport.AMQP.Supervisor do
  use Supervisor
  import Farmbot.System.ConfigStorage
  alias Farmbot.BotState.Transport.AMQP.{ConnectionWorker, ChannelSupervisor}

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def stop(reason \\ :normal) do
    if Process.whereis(__MODULE__) do
      Supervisor.stop(__MODULE__)
    else
      :ok
    end
  end

  def init([]) do
    token = get_config_value(:string, "authorization", "token")
    email = get_config_value(:string, "authorization", "email")
    children = [
      {Farmbot.AMQP.ConnectionWorker, [token: token, email: email]},
      {Farmbot.AMQP.ChannelSupervisor, [token]}
    ]
    Supervisor.init(children, [strategy: :one_for_all])
  end
end

defmodule Farmbot.BotState.Transport.AMQP.AutoSyncTransport do
  @moduledoc false
  use GenServer
  use AMQP
  use Farmbot.Logger
  require Elixir.Logger
  import Farmbot.System.ConfigStorage,
    only: [get_config_value: 3, update_config_value: 4]

  @exchange "amq.topic"

  defstruct [:conn, :chan, :bot]
  alias __MODULE__, as: State

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([conn, jwt]) do
    Process.flag(:sensitive, true)
    {:ok, chan}  = AMQP.Channel.open(conn)
    :ok          = Basic.qos(chan, [global: true])
    {:ok, _}     = AMQP.Queue.declare(chan, jwt.bot <> "_auto_sync", [auto_delete: false])
    :ok          = AMQP.Queue.bind(chan, jwt.bot <> "_auto_sync", @exchange, [routing_key: "bot.#{jwt.bot}.sync.#"])
    {:ok, _tag}  = Basic.consume(chan, jwt.bot <> "_auto_sync", self(), [no_ack: true])
    {:ok, struct(State, [conn: conn, chan: chan, bot: jwt.bot])}
  end

  def terminate(_reason, _state) do
    # update_config_value(:bool, "settings", "needs_http_sync", true)
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, _}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is
  # unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, _}, state) do
    {:stop, :normal, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, _}, state) do
    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, %{routing_key: key}}, state) do
    device = state.bot
    ["bot", ^device, "sync", asset_kind, id_str] = String.split(key, ".")
    id = String.to_integer(id_str)
    data = Farmbot.JSON.decode!(payload)
    body = data["body"]
    state = case asset_kind do
      "FbosConfig" when is_nil(body) ->
        Farmbot.Logger.error 1, "FbosConfig deleted via API?"
        state

      "FbosConfig" ->
        handle_fbos_config(id, payload, state)

      "FirmwareConfig" when is_nil(body) ->
        Farmbot.Logger.error 1, "FirmwareConfig deleted via API?"
        state

      "FirmwareConfig" ->
        handle_fw_config(id, payload, state)

      _ ->
        handle_sync_cmd(asset_kind, id, payload, state)
    end

    json = Farmbot.JSON.encode!(%{args: %{label: data["args"]["label"]}, kind: "rpc_ok"})
    :ok = AMQP.Basic.publish state.chan, @exchange, "bot.#{device}.from_device", json
    {:noreply, state}
  end

  def handle_fbos_config(_, _, %{state_cache: nil} = state) do
    # Don't update fbos config, if we don't have a state cache for whatever reason.
    {:noreply, [], state}
  end

  def handle_fbos_config(_id, payload, state) do
    if get_config_value(:bool, "settings", "ignore_fbos_config") do
      IO.puts "Ignoring OS config from AMQP."
      state
    else
      case Farmbot.JSON.decode(payload) do
        {:ok, %{"body" => %{"api_migrated" => true} = config}} ->
          # Logger.info 1, "Got fbos config from amqp: #{inspect config}"
          old = state.configuration
          updated = Farmbot.Bootstrap.SettingsSync.apply_fbos_map(old, config)
          push_bot_state(state.chan, state.bot, %{state.state_cache | configuration: updated})
          state
        _ -> state
      end
    end
  end

  def handle_fw_config(_id, payload, state) do
    if get_config_value(:bool, "settings", "ignore_fw_config") do
      IO.puts "Ignoring FW config from AMQP."
      state
    else
      case Farmbot.JSON.decode(payload) do
        {:ok, %{"body" => %{} = config}} ->
          old = state.state_cache.mcu_params
          _new = Farmbot.Bootstrap.SettingsSync.apply_fw_map(old, config)
          state
        _ -> state
        end
    end
  end

  @doc false
  def handle_sync_cmd(kind, id, payload, state) do
    mod = Module.concat(["Farmbot", "Asset", kind])
    if Code.ensure_loaded?(mod) do
      %{
        "body" => body,
        "args" => %{"label" => uuid}
      } = Farmbot.JSON.decode!(payload, as: %{"body" => struct(mod)})

      _cmd = ConfigStorage.register_sync_cmd(String.to_integer(id), kind, body)
      # This if statment should really not live here..
      if get_config_value(:bool, "settings", "auto_sync") do
        Farmbot.Repo.fragment_sync()
      else
        Farmbot.BotState.set_sync_status(:sync_now)
      end
    else
      Logger.error 3, "Failed to load #{mod}"
    end
    state
  end
end

defmodule Farmbot.Target.NervesHubHandler do
  @behaviour Farmbot.System.NervesHub
  require Logger

  def serial_number(plat) do
    :os.cmd('/usr/bin/boardid -b uboot_env -u nerves_serial_number -b uboot_env -u serial_number -b #{plat} -n 4')
    |> to_string()
    |> String.trim()
  end

  def serial_number, do: serial_number("rpi")

  def connect do
    Logger.info "Starting NervesHub app."
    # Stop Nerves Hub if it is running.
    _ = Application.stop(:nerves_hub)
    # Cause NervesRuntime.KV to restart.
    _ = GenServer.stop(Nerves.Runtime.KV)
    {:ok, _} = Application.ensure_all_started(:nerves_hub)
    Process.sleep(1000)
    _ = NervesHub.connect()
    Logger.info "NervesHub started."
    :ok
  end

  def provision(serial) do
    Nerves.Runtime.KV.UBootEnv.put("nerves_serial_number", serial)
    Nerves.Runtime.KV.UBootEnv.put("nerves_fw_serial_number", serial)
  end

  def configure_certs(cert, key) do
    Nerves.Runtime.KV.UBootEnv.put("nerves_hub_cert", cert)
    Nerves.Runtime.KV.UBootEnv.put("nerves_hub_key", key)
    :ok
  end

  def deconfigure() do
    Nerves.Runtime.KV.UBootEnv.put("nerves_hub_cert", "")
    Nerves.Runtime.KV.UBootEnv.put("nerves_hub_key", "")
    Nerves.Runtime.KV.UBootEnv.put("nerves_serial_number", "")
    Nerves.Runtime.KV.UBootEnv.put("nerves_fw_serial_number", "")
    :ok
  end

  def config() do
    [
      Nerves.Runtime.KV.get("nerves_hub_serial_number"),
      Nerves.Runtime.KV.get("nerves_fw_serial_number"),
      Nerves.Runtime.KV.get("nerves_hub_cert"),
      Nerves.Runtime.KV.get("nerves_hub_key"),
    ]
  end
end

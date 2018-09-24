defmodule Farmbot.System.NervesHub do
  @provisioner Application.get_env(:farmbot, :behaviour)[:nerves_hub_provisioner]
  || Mix.raise("missing :nerves_hub_provisioner module")

  @config Application.get_env(:farmbot, __MODULE__, [])

  @callback serial_number() :: String.t()

  use GenServer
  require Logger

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    send self(), :configure
    {:ok, :not_configured}
  end

  def handle_info(:configure, :not_configured) do
    server = Farmbot.System.ConfigStorage.get_config_value(:string, "authorization", "server")
    if server && Process.whereis(Farmbot.HTTP) do
      server_env = @config[:server_env] || case URI.parse(server) do
        %{host: "my.farm.bot"}        -> "server:production"
        %{host: "my.farmbot.io"}      -> "server:production"
        %{host: "staging.farm.bot"}   -> "server:staging"
        %{host: "staging.farmbot.io"} -> "server:staging"
        _ -> "server:production"
      end

      app_env = @config[:app_env] || "application:#{Farmbot.Project.env()}"
      extra_tags = @config[:extra_tags] || []

      config = [
        Nerves.Runtime.KV.get("nerves_hub_serial_number"),
        Nerves.Runtime.KV.get("nerves_fw_serial_number"),
        Nerves.Runtime.KV.get("nerves_hub_cert"),
        Nerves.Runtime.KV.get("nerves_hub_key"),
      ]
      if "" in config do
        :ok = deconfigure()
        :ok = provision()
        :ok = configure([app_env, server_env] ++ extra_tags)
      else
        NervesHub.connect()
      end

      {:noreply, :configured}
    else
      Logger.warn "Server not configured yet. Waiting 10_000 ms to try again."
      Process.send_after(self(), :configure, 10_000)
      {:noreply, :not_configured}
    end
  end

  # Returns the current serial number.
  def serial do
    @provisioner.serial_number()
  end

  # Sets Serial number in environment.
  def provision do
    Nerves.Runtime.KV.UBootEnv.put("nerves_serial_number", serial())
    Nerves.Runtime.KV.UBootEnv.put("nerves_fw_serial_number", serial())
    :ok
  end

  # Creates a device in NervesHub
  # or updates it if one exists.
  def configure(tags) when is_list(tags) do
    Logger.info "Configuring NervesHub: #{inspect tags}"
    payload = %{
      serial_number: serial(),
      tags: tags
    } |> Farmbot.JSON.encode!()
    Farmbot.HTTP.post("/api/device_cert", payload)
  end

  # Message comes over AMQP.
  def configure_certs(%{"cert" => cert, "key" => key}) do
    Nerves.Runtime.KV.UBootEnv.put("nerves_hub_cert", cert)
    Nerves.Runtime.KV.UBootEnv.put("nerves_hub_key", key)
    :ok
  end

  def deconfigure do
    Nerves.Runtime.KV.UBootEnv.put("nerves_hub_cert", "")
    Nerves.Runtime.KV.UBootEnv.put("nerves_hub_key", "")
    Nerves.Runtime.KV.UBootEnv.put("nerves_serial_number", "")
    Nerves.Runtime.KV.UBootEnv.put("nerves_fw_serial_number", "")
    :ok
  end
end

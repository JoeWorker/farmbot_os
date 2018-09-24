defmodule Farmbot.Target.NervesHubProvisioner do
  @behaviour Farmbot.System.NervesHub

  def serial_number(plat) do
    :os.cmd('/usr/bin/boardid -b uboot_env -u nerves_serial_number -b uboot_env -u serial_number -b #{plat} -n 4')
    |> to_string()
    |> String.trim()
  end

  def serial_number, do: serial_number("rpi")
end

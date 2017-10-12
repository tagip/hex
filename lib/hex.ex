defmodule Hex do
  use Application

  def start() do
    {:ok, _} = Application.ensure_all_started(:hex)
  end

  def stop() do
    case Application.stop(:hex) do
      :ok -> :ok
      {:error, {:not_started, :hex}} -> :ok
    end
  end

  def start(_, _) do
    dev_setup()

    Mix.SCM.append(Hex.SCM)
    Mix.RemoteConverger.register(Hex.RemoteConverger)

    Hex.Version.start()
    start_httpc()

    opts = [strategy: :one_for_one, name: Hex.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  def version(), do: unquote(Mix.Project.config[:version])
  def elixir_version(), do: unquote(System.version)
  def otp_version(), do: unquote(Hex.Utils.otp_version)

  defp start_httpc do
    :inets.start(:httpc, profile: :hex)
    opts = [
      max_sessions: 8,
      max_keep_alive_length: 4,
      keep_alive_timeout: 120_000,
    ]
    :httpc.set_options(opts, :hex)
  end

  if Version.compare(System.version, "1.3.0") == :lt do
    def string_trim(string), do: String.strip(string)
    def to_charlist(term), do: Kernel.to_char_list(term)
    def string_to_charlist(string), do: String.to_char_list(string)
  else
    def string_trim(string), do: String.trim(string)
    def to_charlist(term), do: Kernel.to_charlist(term)
    def string_to_charlist(string), do: String.to_charlist(string)
  end

  if Version.compare(System.version, "1.4.0") == :lt do
    def enum_split_with(enum, fun), do: Enum.partition(enum, fun)
  else
    def enum_split_with(enum, fun), do: Enum.split_with(enum, fun)
  end

  if Mix.env == :test do
    defp children do
      import Supervisor.Spec
      [
        worker(Hex.State, []),
        worker(Hex.Parallel, [:hex_fetcher])
      ]
    end
  else
    defp children do
      import Supervisor.Spec
      [
        worker(Hex.State, []),
        worker(Hex.Parallel, [:hex_fetcher]),
        worker(Hex.Registry.Server, []),
        worker(Hex.UpdateChecker, [])
      ]
    end
  end

  if Mix.env in [:dev, :test] do
    defp dev_setup do
      :erlang.system_flag(:backtrace_depth, 20)
    end
  else
    defp dev_setup, do: :ok
  end
end

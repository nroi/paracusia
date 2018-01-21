defmodule Paracusia do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # subscriptions are stored in an agent in order to retain them during restarts.
    {:ok, agent} = Agent.start_link(fn -> [] end)

    children = [
      worker(Paracusia.MpdClient, [mpd_client_options()]),
      worker(Paracusia.PlayerState, [agent])
    ]

    opts = [strategy: :rest_for_one, name: Paracusia.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp mpd_client_options do
    [
      retry_after: Application.fetch_env!(:paracusia, :retry_after),
      max_attempts: Application.fetch_env!(:paracusia, :max_retry_attempts)
    ]
  end
end

defmodule Paracusia do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Paracusia.MpdClient, [[retry_after: 100, max_attempts: 3]]),
      worker(Paracusia.PlayerState, [])
    ]

    opts = [strategy: :rest_for_one, name: Paracusia.Supervisor]
    Supervisor.start_link(children, opts)
  end

end

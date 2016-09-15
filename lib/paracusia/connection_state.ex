defmodule Paracusia.ConnectionState do
  defstruct sock_passive: nil,
            sock_active: nil,
            genevent_pid: nil,
            status: nil
end

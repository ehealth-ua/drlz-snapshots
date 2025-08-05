defmodule DRLZ do
  use Application

  def start(_, _) do
      children = [ ]
      opts = [strategy: :one_for_one, name: App.Supervisor]
      :io.format "DRLZ Medical Registry System Client [https://drlz.info/api/docs].~n"
      Supervisor.start_link(children, opts)
  end
end

defmodule DRLZ do
  use Application
  def start(_, _) do
      :logger.add_handlers(:drlz)
      children = [ ]
      opts = [strategy: :one_for_one, name: App.Supervisor]
      {:ok, bearer} = :application.get_env(:drlz, :bearer)
      IO.puts "ESOZ DEC DRLZ SYNC: https://drlz.info/api/docs"
      IO.puts "Bearer: #{bearer}"
      Supervisor.start_link(children, opts)
  end
end

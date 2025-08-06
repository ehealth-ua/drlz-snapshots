defmodule DRLZ do
  use Application
  def start(_, _) do
      children = [ ]
      opts = [strategy: :one_for_one, name: App.Supervisor]
      {:ok, bearer} = :application.get_env(:drlz, :bearer)
      :io.format "DRLZ Medical Registry System Client: https://drlz.info/api/docs.~n"
      :io.format "Bearer: #{String.replace(:erlang.iolist_to_binary(bearer), "Bearer ", "")}.~n"
      Supervisor.start_link(children, opts)
  end
end

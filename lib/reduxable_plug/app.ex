defmodule ReduxablePlug.App do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Task.Supervisor, [[name: ReduxablePlug.BackgroundJob.supervisor_name()]])
    ]

    opts = [strategy: :one_for_one, name: ReduxablePlug.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

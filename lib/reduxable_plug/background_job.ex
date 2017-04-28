defmodule ReduxablePlug.BackgroundJob do
  def send(fun) do
    Task.Supervisor.start_child supervisor_name(), fun
  end

  def supervisor_name do
    ReduxablePlug.TaskSupervisor
  end
end

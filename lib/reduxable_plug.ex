defmodule ReduxablePlug do
  def put_client_identifier(conn, client_identifier) do
    Plug.Conn.put_private conn, :reduxable_client_identifier, client_identifier
  end

  def init(_opts) do
  end

  def call(conn, _opts) do
    ReduxablePlug.BackgroundJob.send fn() ->
      payload = conn |> extract_event_payload
      HTTPoison.post endpoint() <> "pipeline/actions",
        Poison.encode!(payload),
        [
          {"Content-Type", "application/json"},
          {"reduxable-identifier", identifier()},
          {"reduxable-client-identifier", get_client_identifier(conn)}
        ]
      end
    conn
  end

  defp extract_event_payload(conn) do
    %{
      type: controller_action(conn),
      params: conn.params
    }
  end

  defp controller_action(conn) do
    controller = conn.private.phoenix_controller
      |> to_string()
      |> String.replace(~r/^Elixir\./, "")
    "#{controller}##{conn.private.phoenix_action}"
  end

  defp endpoint do
    Application.get_env(:reduxable_plug, :endpoint, "http://localhost:4000/")
  end

  defp identifier do
    Application.fetch_env!(:reduxable_plug, :identifier)
  end

  defp get_client_identifier(conn) do
    conn.private.reduxable_client_identifier
  end
end

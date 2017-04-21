defmodule ReduxablePlugTest do
  use ExUnit.Case
  doctest ReduxablePlug

  setup do
    bypass = Bypass.open
    Application.put_env(:reduxable_plug, :endpoint, endpoint_url(bypass.port))
    {:ok, bypass: bypass}
  end

  test "put_client_identifier on connection" do
    conn = build_conn() |> ReduxablePlug.put_client_identifier("user123")
    assert conn.private.reduxable_client_identifier == "user123"
  end

  test "sends the payload to reduxable", %{bypass: bypass} do
    set_redux_identifier "identifier123"
    conn = build_conn(:get, "/users", %{name: "Joe"})
      |> Plug.Conn.put_private(:phoenix_controller, MyApp.Web.FooController)
      |> Plug.Conn.put_private(:phoenix_action, :new)
      |> ReduxablePlug.put_client_identifier("user123")
    stub_action_endpoint(bypass)

    ReduxablePlug.call(conn, %{})

    conn = get_request_to_action_endpoint()
    assert conn.request_path == "/pipeline/actions"
    assert conn.method == "POST"
    assert conn.params == %{"type" => "MyApp.Web.FooController#new", "params" => %{"name" => "Joe"}}
    assert reduxable_identifier(conn) == "identifier123"
    assert reduxable_client_identifier(conn) == "user123"
  end

  test "only removes Elixir. from beginning of module name", %{bypass: bypass} do
    set_redux_identifier "identifier123"
    conn = build_conn(:get, "/users", %{name: "Joe"})
      |> Plug.Conn.put_private(:phoenix_controller, MyApp.AwesomeElixir.FooController)
      |> Plug.Conn.put_private(:phoenix_action, :new)
      |> ReduxablePlug.put_client_identifier("user123")

    stub_action_endpoint(bypass)

    ReduxablePlug.call(conn, %{})

    conn = get_request_to_action_endpoint()
    assert conn.params == %{"type" => "MyApp.AwesomeElixir.FooController#new", "params" => %{"name" => "Joe"}}
  end

  def set_redux_identifier(identifier) do
    Application.put_env(:reduxable_plug, :identifier, identifier)
  end

  def stub_action_endpoint(bypass) do
    test_process = self()
    Bypass.expect bypass, fn conn ->
      send test_process, {:reduxable_request, conn}
      Plug.Conn.resp(conn, 200, "")
    end
  end

  def get_request_to_action_endpoint do
    assert_receive {:reduxable_request, conn}
    conn |> parse_json_params
  end

  def build_conn do
    Plug.Test.conn :get, "/doesnt_matter"
  end

  def build_conn(method, path, params) do
    Plug.Test.conn(method, path, params) |> parse_params
  end

  def reduxable_identifier(conn) do
    Plug.Conn.get_req_header(conn, "reduxable-identifier") |> List.first
  end

  def reduxable_client_identifier(conn) do
    Plug.Conn.get_req_header(conn, "reduxable-client-identifier") |> List.first
  end

  def parse_params(conn) do
    conn |> Plug.Parsers.call(parsers: [:urlencoded])
  end

  def parse_json_params(conn) do
    Plug.Parsers.call(conn, parsers: [Plug.Parsers.JSON], json_decoder: Poison)
  end

  def endpoint_url(port), do: "http://localhost:#{port}/"
end

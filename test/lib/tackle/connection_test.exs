defmodule Tackle.ConnectionTest do
  use ExUnit.Case
  doctest Tackle.Connection, import: true

  setup do
    Tackle.Connection.reset()
  end

  test "default connection name returns new process for each call" do
    pid = get_connection_pid(:default)
    assert get_connection_pid(:default) != pid
  end

  test "non default connection name returns same process for each call" do
    pid = get_connection_pid(:foo)
    assert get_connection_pid(:foo) == pid
  end

  test "connection process died -> create new one" do
    pid = get_connection_pid(:bar)
    Process.exit(pid, :kill)
    assert get_connection_pid(:bar) != pid
  end

  def get_connection_pid(name) do
    Tackle.Connection.open(name, []) |> get_pid
  end

  def get_pid({:ok, connection}) do
    connection.pid
  end
end

defmodule Ztripwire.LogTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  setup do
    base =
      Path.join(System.tmp_dir!(), "ztripwire-log-test-#{:erlang.unique_integer([:positive])}")

    test_path = Path.join(base, "test")
    error_path = Path.join(base, "errors")
    previous = Application.get_env(:ztripwire, Ztripwire.Log, [])

    Application.put_env(:ztripwire, Ztripwire.Log,
      service: "ztripwire-test",
      sample_rate: 1.0,
      test_path: test_path,
      error_path: error_path
    )

    on_exit(fn ->
      Application.put_env(:ztripwire, Ztripwire.Log, previous)
      File.rm_rf!(base)
    end)

    {:ok, %{test_path: test_path, error_path: error_path}}
  end

  test "new/1 builds a wide event with base fields" do
    event = Ztripwire.Log.new(%{request_id: "req_1", user_id: "user_123"})
    assert event.request_id == "req_1"
    assert event.user_id == "user_123"
    assert event.service == "ztripwire-test"
    assert is_binary(event.timestamp)
    assert is_binary(event.node)
  end

  test "info/1 writes JSONL to the test path", %{test_path: test_path} do
    capture_io(fn ->
      assert {:ok, _} = Ztripwire.Log.info(%{message: "request completed", status: 200})
    end)

    [file] = Path.wildcard(Path.join(test_path, "*.jsonl"))
    [line] = file |> File.read!() |> String.split("\n", trim: true)
    decoded = Jason.decode!(line)
    assert decoded["message"] == "request completed"
    assert decoded["status"] == 200
    assert decoded["level"] == "info"
  end

  test "error/1 writes JSONL to the error path", %{error_path: error_path} do
    capture_io(fn ->
      assert {:ok, _} = Ztripwire.Log.error(%{message: "pool exhausted", service: "postgres"})
    end)

    [file] = Path.wildcard(Path.join(error_path, "*.jsonl"))
    [line] = file |> File.read!() |> String.split("\n", trim: true)
    decoded = Jason.decode!(line)
    assert decoded["message"] == "pool exhausted"
    assert decoded["level"] == "error"
  end

  test "pretty print colors keys, values, and value types" do
    output =
      capture_io(fn ->
        Ztripwire.Log.info(%{
          message: "types",
          count: 3,
          active: true,
          missing: nil,
          name: "ztripwire"
        })
      end)

    assert output =~ "INFO"
    assert output =~ "types"
    assert output =~ "count"
    assert output =~ "\e["
  end

  test "keep?/2 always keeps errors and slow requests" do
    assert Ztripwire.Log.keep?(:error, %{message: "boom"})
    assert Ztripwire.Log.keep?(:info, %{duration_ms: 5_000})
    assert Ztripwire.Log.keep?(:warning, %{message: "slow"})
  end
end

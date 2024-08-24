defmodule HedgexTest do
  use ExUnit.Case

  describe "capture/1" do
    test "returns :ok on success" do
      Req.Test.stub(Hedgex, fn conn -> Req.Test.json(conn, %{}) end)

      assert :ok ==
               Hedgex.capture(%{
                 event: "foo",
                 distinct_id: 12345,
                 properties: %{foo_key: "bar", batch: false}
               })
    end

    test "returns posthog error with status code and body" do
      Req.Test.stub(Hedgex, fn conn -> Plug.Conn.send_resp(conn, 401, "message") end)

      assert {:error, %{status: 401, body: "message"}} =
               Hedgex.capture(%{
                 distinct_id: 12345,
                 properties: %{foo_key: "bar", batch: false}
               })
    end
  end

  describe "batch/1" do
    test "returns :ok on success" do
      Req.Test.stub(Hedgex, fn conn -> Req.Test.json(conn, %{}) end)

      assert :ok == Hedgex.batch([%{event: "foo", distinct_id: 12345}])
    end

    test "returns posthog error with status code and body" do
      Req.Test.stub(Hedgex, fn conn -> Plug.Conn.send_resp(conn, 401, "message") end)

      assert {:error, %{status: 401, body: "message"}} =
               Hedgex.batch([%{event: "foo", distinct_id: 12345}])
    end
  end

  describe "decide/1" do
    test "returns the body on success" do
      decide_response = %{"featureFlags" => %{"my-awesome-flag" => true}}

      Req.Test.stub(Hedgex, fn conn ->
        Req.Test.json(conn, %{"featureFlags" => %{"my-awesome-flag" => true}})
      end)

      assert {:ok, decide_response} == Hedgex.decide(12345)
    end

    test "returns posthog error with status code and body" do
      Req.Test.stub(Hedgex, fn conn -> Plug.Conn.send_resp(conn, 401, "message") end)

      assert {:error, %{status: 401, body: "message"}} =
               Hedgex.batch([%{event: "foo", distinct_id: 12345}])
    end
  end
end

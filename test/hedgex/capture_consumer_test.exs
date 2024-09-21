defmodule Hedgex.CaptureConsumerTest do
  use ExUnit.Case, async: true

  describe "Hedgex.CaptureConsumer" do
    @describetag capture_log: true

    setup context do
      pid = self()
      test_name = context.test

      :telemetry.attach(
        test_name,
        [:hedgex, :capture, :flush, :stop],
        fn _event, _measures, metadata, _config ->
          send(pid, metadata)
        end,
        :no_config
      )

      on_exit(fn -> :telemetry.detach(test_name) end)

      Req.Test.stub(Hedgex.Api, fn conn -> Req.Test.json(conn, %{}) end)
    end

    test "flushes after the configured number of records" do
      {:ok, capture} = GenStage.start_link(Hedgex.Capture, [])

      {:ok, consumer} =
        GenStage.start_link(Hedgex.CaptureConsumer,
          subscribe_to: capture,
          # long interval to ensure we never flush from the timer
          flush_interval: 1000 * 60 * 24,
          flush_batch_size: 2
        )

      Req.Test.allow(Hedgex.Api, self(), consumer)

      batch_1 = [%{event: "1", distinct_id: 1}, %{event: "2", distinct_id: 2}]
      Enum.each(batch_1, &GenStage.call(capture, {:capture, &1}))
      assert_event_meta(batch_1)

      batch_2 = [%{event: "3", distinct_id: 3}, %{event: "4", distinct_id: 4}]
      Enum.each(batch_2, &GenStage.call(capture, {:capture, &1}))
      assert_event_meta(batch_2)
    end

    test "flushes after the configured time" do
      {:ok, capture} = GenStage.start_link(Hedgex.Capture, [])

      {:ok, consumer} =
        GenStage.start_link(Hedgex.CaptureConsumer,
          subscribe_to: capture,
          flush_interval: 100,
          flush_batch_size: 99999
        )

      Req.Test.allow(Hedgex.Api, self(), consumer)

      assert_duration(100, 50, fn ->
        event = %{event: "1", distinct_id: 1}
        GenStage.call(capture, {:capture, event})
        assert_event_meta([event], 500)
      end)

      assert_duration(100, 50, fn ->
        event = %{event: "2", distinct_id: 2}
        GenStage.call(capture, {:capture, event})
        assert_event_meta([event], 500)
      end)
    end
  end

  defp assert_duration(duration, tolerance, fun) do
    start = System.monotonic_time(:millisecond)
    fun.()
    finish = System.monotonic_time(:millisecond)

    actual = finish - start
    assert actual <= duration + tolerance
    assert actual >= duration - tolerance
  end

  defp assert_event_meta(events, timeout \\ 100) do
    assert_receive metadata, timeout
    assert MapSet.equal?(MapSet.new(metadata.events), MapSet.new(events))
  end
end

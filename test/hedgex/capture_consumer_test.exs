defmodule Hedgex.CaptureConsumerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

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

    test "drops events that are too big" do
      {:ok, capture} = GenStage.start_link(Hedgex.Capture, [])

      {:ok, consumer} =
        GenStage.start_link(Hedgex.CaptureConsumer,
          subscribe_to: capture,
          flush_batch_size: 2
        )

      Req.Test.allow(Hedgex.Api, self(), consumer)

      event = %{event: "1", distinct_id: 1}
      big = %{event: "2", distinct_id: 2, properties: %{"f" => String.duplicate("a", 501 * 1024)}}

      assert capture_log(fn ->
               GenStage.call(capture, {:capture, event})
               GenStage.call(capture, {:capture, big})
               assert_event_meta([event], 500)
             end) =~ "exceeded max size"
    end

    test "splits requests when a single batch is too big" do
      {:ok, capture} = GenStage.start_link(Hedgex.Capture, [])

      {:ok, consumer} =
        GenStage.start_link(Hedgex.CaptureConsumer,
          subscribe_to: capture,
          flush_batch_size: 10000,
          flush_interval: 250
        )

      Req.Test.allow(Hedgex.Api, self(), consumer)

      # Aiming for two batches in a single flush op:
      # - ~250KB per event so 4 events = ~1MB
      # - max batch size = 10MB, so ~40 events = 1 batch
      # - 50 events gets 1 batch + some change for a second
      events =
        Enum.map(1..50, fn i ->
          %{
            event: "#{i}",
            distinct_id: i,
            properties: %{"#{i}" => String.duplicate("a", 250 * 1024)}
          }
        end)

      Enum.each(events, &GenStage.call(capture, {:capture, &1}))
      assert_receive metadata1, 500
      assert_receive metadata2, 500

      expected_metadata =
        events
        |> Enum.map(&Map.take(&1, [:event, :distinct_id]))
        |> MapSet.new()

      actual_metadata =
        metadata1.events
        |> Enum.concat(metadata2.events)
        |> Enum.map(&Map.take(&1, [:event, :distinct_id]))
        |> MapSet.new()

      assert expected_metadata == actual_metadata
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

    actual_meta =
      events
      |> Enum.map(&Map.take(&1, [:event, :distinct_id]))
      |> MapSet.new()

    assert MapSet.equal?(MapSet.new(metadata.events), actual_meta)
  end
end

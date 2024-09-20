defmodule Hedgex.CaptureTest do
  use ExUnit.Case, async: true

  defmodule Forwarder do
    use GenStage

    def start_link(init, opts \\ []) do
      GenStage.start_link(__MODULE__, init, opts)
    end

    def ask(forwarder, to, n) do
      GenStage.call(forwarder, {:ask, to, n})
    end

    def init(init) do
      init
    end

    def handle_call({:ask, to, n}, _, state) do
      GenStage.ask(to, n)
      {:reply, :ok, [], state}
    end

    def handle_subscribe(:producer, opts, from, recipient) do
      send(recipient, {:consumer_subscribed, from})
      {Keyword.get(opts, :consumer_demand, :automatic), recipient}
    end

    def handle_events(events, _from, recipient) do
      send(recipient, {:consumed, events})
      {:noreply, [], recipient}
    end
  end

  describe "Hedgex.Capture.capture/1" do
    test "auto-forwards events when there's sufficient demand" do
      {:ok, stage} = GenStage.start_link(Hedgex.Capture, [])
      {:ok, _forwarder} = Forwarder.start_link({:consumer, self(), subscribe_to: [stage]})

      assert_receive {:consumer_subscribed, _sub}

      event1 = %{event: "1", distinct_id: 1, timestamp: DateTime.utc_now()}
      assert :ok = GenStage.call(stage, {:capture, event1})
      assert_receive {:consumed, [^event1]}

      event2 = %{event: "2", distinct_id: 2, timestamp: DateTime.utc_now()}
      assert :ok = GenStage.call(stage, {:capture, event2})
      assert_receive {:consumed, [^event2]}
    end

    test "buffers and sends outstanding events if demand is not immediately available" do
      {:ok, stage} = GenStage.start_link(Hedgex.Capture, [])

      {:ok, forwarder} =
        Forwarder.start_link(
          {:consumer, self(), subscribe_to: [{stage, consumer_demand: :manual}]}
        )

      assert_receive {:consumer_subscribed, sub}

      events = Enum.map(1..5, &%{event: "#{&1}", distinct_id: &1, timestamp: DateTime.utc_now()})
      Enum.each(events, fn event -> assert :ok = GenStage.call(stage, {:capture, event}) end)
      Forwarder.ask(forwarder, sub, 5)

      assert_receive {:consumed, ^events}
    end

    test "returns error when queue is full" do
      {:ok, stage} = GenStage.start_link(Hedgex.Capture, max_queue_size: 1)

      req = {:capture, %{event: "1", distinct_id: 1}}
      assert :ok = GenStage.call(stage, req)
      assert {:error, :queue_full} = GenStage.call(stage, req)
    end
  end
end

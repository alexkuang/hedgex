defmodule Hedgex.CaptureConsumer do
  use GenStage

  require Logger

  # PostHog max event size is 1MB, use 500KB limit to be conservative
  # https://posthog.com/docs/data/ingestion-warnings#discarded-event-exceeding-1mb-limit
  @max_encoded_size 500 * 1024

  # PostHog max batch request size is 20MB, so use 10MB to be conservative
  # https://posthog.com/docs/api/capture
  @max_encoded_batch_size 10 * 1024 * 1024

  @type state :: %{
          :queue => :queue.queue(),
          :queue_size => pos_integer | 0,
          :next_flush_timer => reference | nil,
          :flush_interval => pos_integer,
          :flush_batch_size => pos_integer
        }

  @type options :: [
          flush_interval: pos_integer,
          flush_batch_size: pos_integer,
          subscribe_to: atom | {atom, keyword}
        ]

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(init \\ []) do
    GenStage.start_link(__MODULE__, init, name: __MODULE__)
  end

  def init(opts) do
    flush_interval = opts[:flush_interval] || 500

    state = %{
      next_flush_timer: Process.send_after(self(), :flush, flush_interval),
      flush_interval: flush_interval,
      flush_batch_size: opts[:flush_batch_size] || 100,
      queue: :queue.new(),
      queue_size: 0
    }

    {:consumer, state, subscribe_to: [opts[:subscribe_to]]}
  end

  def handle_events(events, _from, state) do
    %{queue_size: size, flush_batch_size: batch_size, queue: queue} = state

    size = size + Enum.count(events)
    queue = :queue.join(queue, :queue.from_list(events))

    if size >= batch_size, do: send(self(), :flush)
    state = Map.merge(state, %{queue: queue, queue_size: size})

    {:noreply, [], state}
  end

  def handle_info(:flush, %{queue: {[], []}} = state) do
    state =
      Map.merge(state, %{
        next_flush_timer: Process.send_after(self(), :flush, state.flush_interval),
        queue: :queue.new(),
        queue_size: 0
      })

    {:noreply, [], state}
  end

  def handle_info(:flush, state) do
    batches =
      state.queue
      |> :queue.to_list()
      |> filter_and_batch()

    Enum.each(batches, fn events ->
      event_meta = %{events: Enum.map(events, &Map.take(&1, [:event, :distinct_id]))}

      :telemetry.span([:hedgex, :capture, :flush], event_meta, fn ->
        %{next_flush_timer: timer} = state

        Hedgex.Api.batch(events)
        :timer.cancel(timer)

        {:ok, event_meta}
      end)
    end)

    state =
      Map.merge(state, %{
        next_flush_timer: Process.send_after(self(), :flush, state.flush_interval),
        queue: :queue.new(),
        queue_size: 0
      })

    {:noreply, [], state}
  end

  defp filter_and_batch(events) do
    with_size =
      Enum.map(events, fn event ->
        size =
          event
          |> Jason.encode_to_iodata!()
          |> IO.iodata_length()

        {event, size}
      end)

    {dropped, remaining} =
      Enum.split_with(with_size, fn {_, size} -> size > @max_encoded_size end)

    Enum.each(dropped, fn {event, _size} ->
      Logger.warning(
        "Item exceeded max size #{@max_encoded_size} bytes, dropping. event=#{event[:event]} distinct_id=#{event[:distinct_id]}"
      )
    end)

    chunk_fun = fn {event, event_size}, {batch_size, batch} ->
      new_size = event_size + batch_size

      if new_size >= @max_encoded_batch_size do
        {:cont, Enum.reverse([event | batch]), {0, []}}
      else
        {:cont, {new_size, [event | batch]}}
      end
    end

    after_fun = fn
      {_, batch} -> {:cont, Enum.reverse(batch), {0, []}}
    end

    Enum.chunk_while(remaining, {0, []}, chunk_fun, after_fun)
  end
end

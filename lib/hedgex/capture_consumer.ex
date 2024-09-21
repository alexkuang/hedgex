defmodule Hedgex.CaptureConsumer do
  use GenStage

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
    events = :queue.to_list(state.queue)
    event_meta = %{events: Enum.map(events, &Map.take(&1, [:event, :distinct_id]))}

    :telemetry.span([:hedgex, :capture, :flush], event_meta, fn ->
      %{next_flush_timer: timer} = state

      Hedgex.Api.batch(events)
      :timer.cancel(timer)

      state =
        Map.merge(state, %{
          next_flush_timer: Process.send_after(self(), :flush, state.flush_interval),
          queue: :queue.new(),
          queue_size: 0
        })

      {{:noreply, [], state}, event_meta}
    end)
  end
end

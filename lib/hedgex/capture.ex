defmodule Hedgex.Capture do
  @moduledoc """
  Buffered + batched async event pipeline.

  `capture/1` sends the event into a buffer backed by a queue.  Events are drained from the queue and sent to the
  PostHog API when either (1) there are more than `flush_batch_size` events pending, or (2) `flush_interval`
  milliseconds have passed since the previous flush, whichever comes first.

  ## Configuration

  ```elixir
  config :hedgex, :capture,
    max_queue_size: 10000
    # ... etc
  ```

  Options:

  * `max_queue_size`: The size of the queue used to buffer events before sending.  If the queue is full,
  `Hedgex.capture/1` will return an error.  Defaults to 10000.

  * `flush_interval`: Interval in milliseconds for sending events to the API.  Defaults to 500.

  * `flush_batch_size`: Max number of events in the queue before sending events to the API.  This is best-effort and not
  a strict limit.  Defaults to 100.
  """

  use GenStage

  @type state :: %{
          :queue => :queue.queue(),
          :queue_size => pos_integer | 0,
          :pending_demand => pos_integer | 0,
          :max_queue_size => pos_integer
        }

  @type options :: [
          max_queue_size: pos_integer | nil
        ]

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(init \\ []) do
    GenStage.start_link(__MODULE__, init, name: __MODULE__)
  end

  @spec capture(event :: Hedgex.event()) :: :ok | {:error, :queue_full}
  def capture(event) do
    GenStage.call(__MODULE__, {:capture, event})
  end

  ## Callbacks

  def init(opts) do
    state = %{
      queue: :queue.new(),
      queue_size: 0,
      pending_demand: 0,
      max_queue_size: opts[:max_queue_size] || 10000
    }

    {:producer, state}
  end

  @spec handle_call({:capture, event :: Hedgex.event()}, GenServer.from(), state) :: term
  def handle_call({:capture, event}, from, state) do
    %{queue_size: size, max_queue_size: max_size, queue: queue} = state

    # If timestamp is not specified, fill in so it corresponds with the capture call vs when we flush to the API.
    event = Map.put_new(event, :timestamp, DateTime.utc_now())

    if size < max_size do
      {events, state} =
        state
        |> Map.merge(%{queue: :queue.in(event, queue), queue_size: size + 1})
        |> drain_events()

      GenStage.reply(from, :ok)

      {:noreply, events, state}
    else
      {:reply, {:error, :queue_full}, [], state}
    end
  end

  def handle_demand(demand, state) do
    {events, state} =
      state
      |> Map.put(:pending_demand, state.pending_demand + demand)
      |> drain_events()

    {:noreply, events, state}
  end

  defp drain_events(state) do
    %{queue_size: queue_size, queue: queue, pending_demand: demand} = state
    to_take = min(demand, queue_size)
    {taken, queue} = :queue.split(to_take, queue)

    state =
      Map.merge(state, %{
        queue: queue,
        queue_size: queue_size - to_take,
        pending_demand: demand - to_take
      })

    {:queue.to_list(taken), state}
  end
end

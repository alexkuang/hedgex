defmodule Hedgex.CaptureSupervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([]) do
    config = Application.get_env(:hedgex, :capture, [])
    consumer_opts = Keyword.take(config, [:flush_interval, :flush_batch_size])

    children = [
      {Hedgex.Capture, max_queue_size: config[:max_queue_size]},
      {Hedgex.CaptureConsumer, Keyword.put(consumer_opts, :subscribe_to, Hedgex.Capture)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

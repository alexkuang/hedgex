defmodule Hedgex do
  @moduledoc """
  General methods for the Posthog API.
  """

  alias Hedgex.Api
  alias Hedgex.Events

  @type event :: %{
          :event => String.t(),
          :distinct_id => any(),
          optional(:properties) => map,
          optional(:timestamp) => DateTime.t()
        }

  @doc """
  Add metadata `properties` to users in PostHog.

  See: https://posthog.com/docs/api/capture#identify
  """
  def identify(distinct_id, properties) do
    capture(Events.identify(distinct_id, properties))
  end

  @spec capture(event :: Hedgex.event()) :: :ok | {:error, :queue_full}
  defdelegate capture(event), to: Hedgex.Capture

  @spec queue_size() :: pos_integer | 0
  defdelegate queue_size(), to: Hedgex.Capture

  @spec decide(distinct_id :: any(), opts :: Keyword.t()) ::
          {:ok, map()} | {:error, Exception.t()}
  defdelegate decide(distinct_id, opts \\ []), to: Api
end

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

  defdelegate capture(event), to: Hedgex.Capture
  defdelegate decide(distinct_id, opts \\ []), to: Api
end

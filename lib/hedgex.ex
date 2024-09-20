defmodule Hedgex do
  @moduledoc """
  General methods for the Posthog API.

  ## Options

  Common options

    * `:hedgex` - a `Hedgex.Env` containing API configuration. Defaults to a context constructed by application config.
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
  def identify(distinct_id, properties, opts \\ []) do
    capture(Events.identify(distinct_id, properties), opts)
  end

  defdelegate capture(event, opts \\ []), to: Api
  defdelegate batch(events, opts \\ []), to: Api
  defdelegate decide(distinct_id, opts \\ []), to: Api
end

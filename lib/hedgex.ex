defmodule Hedgex do
  @moduledoc """
  General methods for the Posthog API.

  ## Options

  Common options

    * `:hedgex` - a `Hedgex.Env` containing API configuration. Defaults to a context constructed by application config.
  """

  alias Hedgex.Api

  defdelegate capture(event, opts \\ []), to: Api
  defdelegate batch(events, opts \\ []), to: Api
  defdelegate decide(distinct_id, opts \\ []), to: Api
end

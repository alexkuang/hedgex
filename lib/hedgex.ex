defmodule Hedgex do
  @moduledoc """
  General methods for the Posthog API.

  ## Options

  Common options

    * `:hedgex` - a `Hedgex.Env` containing API configuration. Defaults to a context constructed by application config.
  """

  alias Hedgex.Env

  @type event_body :: %{
          :event => String.t(),
          :distinct_id => any(),
          optional(:properties) => map,
          optional(:timestamp) => DateTime.t()
        }

  @doc """
  Send a single event to Posthog.  See https://posthog.com/docs/api/capture#single-event for more details

  ## Examples

      iex> Hedgex.capture(%{event: "foo_created", distinct_id: "user_12345", properties: %{}})
      :ok
  """
  @spec capture(event :: event_body, opts :: Keyword.t()) :: :ok | {:error, map()}
  def capture(event, opts \\ []) do
    env = opts[:hedgex] || Env.new()
    event_body = Map.take(event, [:event, :distinct_id, :properties, :timestamp])

    response =
      [base_url: env.public_endpoint]
      |> Req.new()
      |> Req.post(url: "/capture", json: Map.merge(event_body, %{api_key: env.project_api_key}))

    case response do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: _status, body: body}} -> {:error, body}
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Send a batch of events to Posthog.  See https://posthog.com/docs/api/capture#batch-events for more details

  ## Options

    * `:historical_migration` - defaults to false

  ## Examples

      iex> Hedgex.batch([%{event: "foo_created", distinct_id: "user_12345", properties: %{}}])
      :ok
  """
  @spec batch(batch :: [event_body], opts :: Keyword.t()) :: :ok | {:error, map()}
  def batch(batch, opts \\ []) do
    env = opts[:hedgex] || Env.new()
    historical_migration = opts[:historical_migration] || false

    request_body = %{
      api_key: env.project_api_key,
      historical_migration: historical_migration,
      batch: batch
    }

    response =
      [base_url: env.public_endpoint]
      |> Req.new()
      |> Req.post(url: "/batch", json: request_body)

    case response do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: _status, body: body}} -> {:error, body}
      {:error, err} -> {:error, err}
    end
  end
end

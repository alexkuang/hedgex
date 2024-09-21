defmodule Hedgex.Api do
  @moduledoc """
  Low-level operations for the Posthog API.  This module is meant to be 1:1 with Posthog endpoints:
  https://posthog.com/docs/api

  ## Options

  Common options

    * `:hedgex` - a `Hedgex.Env` containing API configuration. Defaults to a context constructed by application config.
  """

  alias Hedgex.Env

  @doc """
  Send a single event to Posthog.  See https://posthog.com/docs/api/capture#single-event for more details

  ## Examples

      iex> Hedgex.Api.capture(%{event: "foo_created", distinct_id: "user_12345", properties: %{}})
      :ok
  """
  @spec capture(event :: Hedgex.event(), opts :: Keyword.t()) :: :ok | {:error, Exception.t()}
  def capture(event, opts \\ []) do
    env = opts[:hedgex] || Env.new()

    event_body =
      event
      |> Map.take([:event, :distinct_id, :properties, :timestamp])
      |> add_lib_props()

    Env.public_req(env)
    |> Req.post(url: "/capture", json: Map.merge(event_body, %{api_key: env.project_api_key}))
    |> map_req_response(fn _ -> :ok end)
  end

  @doc """
  Send a batch of events to Posthog.  See https://posthog.com/docs/api/capture#batch-events for more details

  ## Options

    * `:historical_migration` - defaults to false

  ## Examples

      iex> Hedgex.Api.batch([%{event: "foo_created", distinct_id: "user_12345", properties: %{}}])
      :ok
  """
  @spec batch(batch :: [Hedgex.event()], opts :: Keyword.t()) :: :ok | {:error, Exception.t()}
  def batch(batch, opts \\ []) do
    env = opts[:hedgex] || Env.new()
    historical_migration = opts[:historical_migration] || false

    request_body = %{
      api_key: env.project_api_key,
      historical_migration: historical_migration,
      batch: Enum.map(batch, &add_lib_props/1)
    }

    Env.public_req(env)
    |> Req.post(url: "/batch", json: request_body)
    |> map_req_response(fn _ -> :ok end)
  end

  @doc """
  Call the public `decide` endpoint used to evaluate feature flag state for a given user.  See
  https://posthog.com/docs/api/decide for more details.

  ## Options

    * `:groups` - (optional) Group config used to evaluate the feature flag

  ## Examples

      iex> Hedgex.Api.decide("user_12345", groups: %{company: "Acme, Inc."}}])
      {:ok, %{"featureFlags" => %{"my-awesome-flag" => true}}}
  """
  @spec decide(distinct_id :: any(), opts :: Keyword.t()) ::
          {:ok, map()} | {:error, Exception.t()}
  def decide(distinct_id, opts \\ []) do
    env = opts[:hedgex] || Env.new()

    request_body = %{
      api_key: env.project_api_key,
      distinct_id: distinct_id,
      groups: opts[:groups]
    }

    Env.public_req(env)
    |> Req.post(url: "/decide", json: request_body)
    |> map_req_response(fn response -> {:ok, response.body} end)
  end

  def map_req_response(response, success_fun) do
    case response do
      {:ok, %{status: 200} = resp} ->
        success_fun.(resp)

      {:ok, %{status: status, body: body}} ->
        {:error, %Hedgex.PosthogError{status: status, body: body}}

      {:error, err} ->
        {:error, %Hedgex.ReqError{error: err}}
    end
  end

  defp add_lib_props(event) do
    event
    |> Map.put_new(:properties, %{})
    |> Map.update!(:properties, &Map.put(&1, "$lib", "hedgex"))
  end
end

defmodule Hedgex.PosthogError do
  @moduledoc """
  An error returned by the Posthog API.
  """

  defexception [:status, :body]

  @type t() :: %__MODULE__{
          status: integer(),
          body: map()
        }

  @impl true
  def message(%__MODULE__{status: status, body: body}) do
    ~s|Error returned by Posthog status=#{status} code=#{body["code"]}: #{body["detail"]}|
  end
end

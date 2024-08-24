defmodule Hedgex.Env do
  @moduledoc """
  Struct holding configuration + environment context.
  """

  defstruct public_endpoint: nil,
            private_endpoint: nil,
            project_api_key: nil,
            personal_api_key: nil

  @typedoc """
  "https://us.i.posthog.com" | "https://eu.i.posthog.com" | your_instance
  """
  @type public_endpoint :: String.t()

  @typedoc """
  "https://us.posthog.com" | "https://eu.posthog.com" | your_instance
  """
  @type private_endpoint :: String.t()

  @type t :: %__MODULE__{
          public_endpoint: public_endpoint | nil,
          private_endpoint: private_endpoint | nil,
          project_api_key: String.t() | nil,
          personal_api_key: String.t() | nil
        }

  @spec new(
          public_endpoint: String.t(),
          private_endpoint: String.t(),
          project_api_key: String.t(),
          personal_api_key: String.t()
        ) :: t()
  def new(opts \\ []) do
    [:public_endpoint, :private_endpoint, :project_api_key, :personal_api_key]
    |> Enum.map(&{&1, opts[&1] || Application.get_env(:hedgex, :public_endpoint)})
    |> Map.new()
    |> then(&struct(__MODULE__, &1))
  end

  @doc """
  Construct a Req.Request for public API calls, e.g. `capture`.  Note that for public calls, the project API key still
  needs to be passed in the body as part of the POST.
  """
  @spec public_req(t()) :: Req.Request.t()
  def public_req(%__MODULE__{} = env) do
    [base_url: env.public_endpoint]
    |> Keyword.merge(Application.get_env(:hedgex, :req_options, []))
    |> Req.new()
  end
end

defmodule Hedgex.Env do
  @moduledoc false

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

  def new(opts \\ []) do
    [:public_endpoint, :private_endpoint, :project_api_key, :personal_api_key]
    |> Enum.map(&{&1, opts[&1] || Application.get_env(:hedgex, :public_endpoint)})
    |> Map.new()
  end
end

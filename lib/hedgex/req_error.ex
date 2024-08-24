defmodule Hedgex.ReqError do
  @moduledoc """
  An HTTP-level error returned by Req
  """

  defexception [:error]

  @type t() :: %__MODULE__{
          error: Exception.t()
        }

  @impl true
  def message(%__MODULE__{error: error}) do
    Exception.message(error)
  end
end

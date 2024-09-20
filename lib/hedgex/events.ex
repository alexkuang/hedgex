defmodule Hedgex.Events do
  @moduledoc """
  Construct common events for the `/capture` endpoint
  """

  @spec identify(distinct_id :: any, properties :: map) :: Hedgex.event()
  def identify(distinct_id, properties) do
    %{
      event: "$identify",
      distinct_id: distinct_id,
      properties: %{
        "$set" => properties
      }
    }
  end
end

# Hedgex

[![hex package](https://img.shields.io/hexpm/v/hedgex.svg)](https://hex.pm/packages/hedgex)
[![hex docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/hedgex/readme.html)
[![ci](https://github.com/alexkuang/hedgex/actions/workflows/ci.yml/badge.svg)](https://github.com/alexkuang/hedgex/actions/)

Posthog client for Elixir.  WIP and highly experimental.

## Installation

```elixir
def deps do
  [
    {:hedgex, "~> 0.1.0"}
  ]
end
```

## Usage

Configure the API:

```elixir
config :hedgex,
  public_endpoint: "https://us.i.posthog.com",
  project_api_key: "abcde12345"
```

Send events:

```elixir
iex> Hedgex.capture(%{event: "foo_created", distinct_id: "user_12345"})
:ok
```

Work with the API directly:

```elixir
# provide creds dynamically
iex(1)> Hedgex.Api.capture(
...(1)>   %{event: "foo_created", distinct_id: "user_12345", properties: %{}},
...(1)>   hedgex: Hedgex.Env.new(public_endpoint: "...", project_api_key: "...")
...(1)> )
:ok
```

## Documentation

[Latest HexDocs](https://hexdocs.pm/hedgex/)

## FAQs

### Is it any good?

Yes.

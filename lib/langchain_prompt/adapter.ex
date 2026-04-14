defmodule LangchainPrompt.Adapter do
  @moduledoc """
  Behaviour for connecting `LangchainPrompt` to a Large Language Model.

  Implement this behaviour to add support for any LLM provider not covered by
  the built-in adapters.

  ## Built-in adapters

  - `LangchainPrompt.Adapters.Langchain` — delegates to any
    [elixir-langchain](https://hex.pm/packages/langchain) chat model.
  - `LangchainPrompt.Adapters.Test` — in-process adapter for ExUnit tests;
    records calls and supports on-demand failure simulation.

  ## Custom adapter example

      defmodule MyApp.Adapters.OpenAIDirect do
        @behaviour LangchainPrompt.Adapter

        @impl true
        def chat(messages, opts) do
          # build request, call API, return {:ok, %Message{}} or {:error, reason}
        end
      end
  """

  alias LangchainPrompt.Message

  @type response :: {:ok, Message.t()} | {:error, any()}

  @callback chat(messages :: list(Message.t()), opts :: map() | keyword()) :: response()
end

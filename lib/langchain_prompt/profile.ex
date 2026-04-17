defmodule LangchainPrompt.Profile do
  @moduledoc """
  Pairs an adapter module with its runtime configuration.

  Returned by `c:LangchainPrompt.Prompt.set_profile/1` to tell `LangchainPrompt.execute/4`
  which adapter and options to use for a given prompt execution.

  ## Fields

  - `:adapter` — a module implementing `LangchainPrompt.Adapter`.
  - `:opts` — a map (or keyword list) passed as-is to `adapter.chat/2`.
    The shape depends on the adapter; see the adapter's documentation.

  ## Example

      %LangchainPrompt.Profile{
        adapter: LangchainPrompt.Adapters.Langchain,
        opts: %{
          chat_module: LangChain.ChatModels.ChatOpenAI,
          model: "gpt-4o-mini",
          temperature: 0.2
        }
      }
  """

  @enforce_keys [:adapter, :opts]
  defstruct [:adapter, :opts]

  @type t :: %__MODULE__{
          adapter: module(),
          opts: map() | keyword()
        }
end

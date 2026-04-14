defmodule LangchainPrompt.Prompt do
  @moduledoc """
  Behaviour for a self-contained, reusable AI task.

  A prompt module encapsulates everything needed for a specific AI operation:
  what to ask (the prompts), how to ask it (the execution profile), and how to
  process the answer (post-processing).

  ## Callbacks

  - `set_profile/1` — returns a `LangchainPrompt.Profile` that selects the
    adapter and model configuration for this task.
  - `generate_system_prompt/1` — returns the system prompt string, or `nil` to
    omit the system message (useful for models that don't support it).
  - `generate_user_prompt/1` — returns the user prompt string, or `nil` for
    conversational prompts where the last message is already in `message_history`.
  - `post_process/2` — transforms the raw `LangchainPrompt.Message` response
    into a domain value. Return `{:ok, result}` or `{:error, reason}`.

  ## Example

      defmodule MyApp.Prompts.Classify do
        @behaviour LangchainPrompt.Prompt

        @impl true
        def set_profile(_assigns), do: MyApp.AIProfiles.get(:fast)

        @impl true
        def generate_system_prompt(_assigns) do
          "Classify the sentiment as :positive, :neutral, or :negative. " <>
          "Reply with exactly one word."
        end

        @impl true
        def generate_user_prompt(%{text: text}), do: text

        @impl true
        def post_process(_assigns, %LangchainPrompt.Message{content: content}) do
          case String.trim(content) do
            "positive" -> {:ok, :positive}
            "neutral"  -> {:ok, :neutral}
            "negative" -> {:ok, :negative}
            other      -> {:error, {:unexpected_response, other}}
          end
        end
      end
  """

  alias LangchainPrompt.Message
  alias LangchainPrompt.Profile

  @callback set_profile(assigns :: map() | struct()) :: Profile.t()
  @callback generate_system_prompt(assigns :: map() | struct()) :: String.t() | nil
  @callback generate_user_prompt(assigns :: map() | struct()) :: String.t() | nil
  @callback post_process(assigns :: map() | struct(), raw_response :: Message.t()) ::
              {:ok, any()} | {:error, any()}
end

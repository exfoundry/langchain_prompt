defmodule LangchainPrompt do
  @moduledoc """
  Execute prompt modules against LLM adapters.

  A prompt module implements the `LangchainPrompt.Prompt` behaviour and
  encapsulates everything for a specific AI task: which model to use
  (`set_profile/1`), what to say (`generate_system_prompt/1`,
  `generate_user_prompt/1`), and how to interpret the result
  (`post_process/2`).

  ## Minimal example

      defmodule MyApp.Prompts.Summarise do
        @behaviour LangchainPrompt.Prompt

        alias LangchainPrompt.Profile
        alias LangchainPrompt.Adapters.Langchain

        @impl true
        def set_profile(_assigns) do
          %Profile{
            adapter: Langchain,
            opts: %{
              chat_module: LangChain.ChatModels.ChatOpenAI,
              model: "gpt-4o-mini"
            }
          }
        end

        @impl true
        def generate_system_prompt(_assigns), do: "You are a concise summariser."

        @impl true
        def generate_user_prompt(%{text: text}), do: "Summarise: \#{text}"

        @impl true
        def post_process(_assigns, %LangchainPrompt.Message{content: content}),
          do: {:ok, content}
      end

      {:ok, summary} = LangchainPrompt.execute(MyApp.Prompts.Summarise, %{text: "..."})

  ## Message history

  Pass prior turns as the third argument to enable conversational prompts:

      history = [
        %LangchainPrompt.Message{role: :user, content: "Hello"},
        %LangchainPrompt.Message{role: :assistant, content: "Hi there!"}
      ]
      LangchainPrompt.execute(MyPrompt, assigns, history)

  ## Attachments

  Pass a list of `LangchainPrompt.Attachment` structs to send files alongside
  the user prompt:

      attachments = [LangchainPrompt.Attachment.from_file!("/tmp/menu.jpg")]
      LangchainPrompt.execute(MyPrompt, assigns, [], attachments)
  """

  alias LangchainPrompt.Attachment
  alias LangchainPrompt.Message
  alias LangchainPrompt.Profile

  @doc """
  Executes a prompt module and returns `{:ok, result}` or `{:error, reason}`.

  Error reasons are tagged tuples:
  - `{:adapter_failure, reason}` — the adapter returned an error
  - `{:post_processing_failure, reason}` — `post_process/2` returned an error
  """
  @spec execute(module(), map() | struct(), list(Message.t()), list(Attachment.t())) ::
          {:ok, any()} | {:error, any()}
  def execute(prompt_module, assigns, message_history \\ [], attachments \\ []) do
    %Profile{adapter: adapter, opts: opts} = prompt_module.set_profile(assigns)

    all_messages = build_messages(prompt_module, assigns, message_history, attachments)

    with {:ok, raw_response} <- call_adapter(adapter, all_messages, opts),
         processed_response <- handle_post_processing(prompt_module, assigns, raw_response) do
      processed_response
    else
      {:error, _reason} = error -> error
      error -> {:error, {:unknown_failure, error}}
    end
  end

  defp build_messages(prompt_module, assigns, message_history, attachments) do
    system_prompt = prompt_module.generate_system_prompt(assigns)
    user_prompt = prompt_module.generate_user_prompt(assigns)

    system_message =
      if system_prompt, do: [%Message{role: :system, content: system_prompt}], else: []

    user_message =
      if user_prompt, do: [build_user_message(user_prompt, attachments)], else: []

    system_message ++ message_history ++ user_message
  end

  defp build_user_message(user_prompt, []) do
    %Message{role: :user, content: user_prompt}
  end

  defp build_user_message(user_prompt, attachments) do
    text_part = %{type: :text, content: user_prompt}

    attachment_parts =
      Enum.map(attachments, fn %Attachment{type: type, content: content, media: media} ->
        %{type: type, content: content, media: media}
      end)

    %Message{role: :user, content: [text_part | attachment_parts]}
  end

  defp call_adapter(adapter, messages, opts) do
    case adapter.chat(messages, opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, {:adapter_failure, reason}}
    end
  end

  defp handle_post_processing(prompt_module, assigns, raw_response) do
    case prompt_module.post_process(assigns, raw_response) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, {:post_processing_failure, reason}}
    end
  end
end

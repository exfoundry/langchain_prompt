defmodule LangchainPrompt.Adapters.Langchain do
  @moduledoc """
  Adapter that delegates to any [elixir-langchain](https://hex.pm/packages/langchain)
  chat model.

  Requires the `:langchain` dependency (`~> 0.7`).

  ## Profile opts

  Pass the following keys in `Profile.opts`:

  | Key            | Required | Description                                      |
  |----------------|----------|--------------------------------------------------|
  | `:chat_module` | yes      | A `LangChain.ChatModels.*` module                |
  | `:model`       | yes      | Model name string                                |
  | any other      | no       | Forwarded as-is to `chat_module.new/1`           |

  ## Examples

      # Google AI
      %Profile{
        adapter: LangchainPrompt.Adapters.Langchain,
        opts: %{
          chat_module: LangChain.ChatModels.ChatGoogleAI,
          model: "gemini-2.0-flash",
          temperature: 0.1
        }
      }

      # OpenAI-compatible (Deepseek, Grok, Mistral, Ollama, …)
      %Profile{
        adapter: LangchainPrompt.Adapters.Langchain,
        opts: %{
          chat_module: LangChain.ChatModels.ChatOpenAI,
          model: "deepseek-chat",
          endpoint: "https://api.deepseek.com/chat/completions",
          api_key: System.get_env("DEEPSEEK_API_KEY")
        }
      }

      # Anthropic
      %Profile{
        adapter: LangchainPrompt.Adapters.Langchain,
        opts: %{
          chat_module: LangChain.ChatModels.ChatAnthropic,
          model: "claude-sonnet-4-6"
        }
      }
  """

  @behaviour LangchainPrompt.Adapter

  alias LangChain.Message, as: LangChainMessage
  alias LangChain.Message.ContentPart
  alias LangchainPrompt.Message

  @impl true
  def chat(messages, opts) do
    {chat_module, model_opts} = Map.pop!(opts, :chat_module)

    with {:ok, model} <- chat_module.new(model_opts),
         langchain_messages <- to_langchain_messages(messages),
         {:ok, [response | _]} <- chat_module.call(model, langchain_messages) do
      {:ok, from_langchain_response(response)}
    end
  end

  defp to_langchain_messages(messages) do
    Enum.map(messages, &to_langchain_message/1)
  end

  defp to_langchain_message(%Message{role: :user, content: content}) when is_binary(content) do
    LangChainMessage.new_user!(content)
  end

  defp to_langchain_message(%Message{role: :user, content: parts}) when is_list(parts) do
    content_parts = Enum.map(parts, &to_content_part/1)
    LangChainMessage.new_user!(content_parts)
  end

  defp to_langchain_message(%Message{role: :assistant, content: content}) do
    LangChainMessage.new_assistant!(content)
  end

  defp to_langchain_message(%Message{role: :system, content: content}) do
    LangChainMessage.new_system!(content)
  end

  defp to_content_part(%{type: :text, content: content}) do
    ContentPart.text!(content)
  end

  defp to_content_part(%{type: :image, content: content, media: media}) do
    ContentPart.image!(content, media: media)
  end

  defp to_content_part(%{type: :file, content: content, media: media}) do
    ContentPart.file!(content, media: media)
  end

  # Plain string content (OpenAI, Deepseek, Grok, Mistral, Ollama, Perplexity)
  defp from_langchain_response(%LangChainMessage{content: content, role: role})
       when is_binary(content) do
    %Message{content: content, role: role}
  end

  # ContentPart list (Google AI, Vertex AI, Anthropic, OpenAI Responses, …)
  # Finds the first text part to handle models that prepend thinking/reasoning parts.
  defp from_langchain_response(%LangChainMessage{content: parts, role: role})
       when is_list(parts) do
    text =
      Enum.find_value(parts, "", fn
        %ContentPart{type: :text, content: content} when is_binary(content) -> content
        _ -> nil
      end)

    %Message{content: text, role: role}
  end
end

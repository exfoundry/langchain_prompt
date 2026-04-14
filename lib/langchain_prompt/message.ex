defmodule LangchainPrompt.Message do
  @moduledoc """
  A single message in a conversation with an LLM.

  `content` is either a plain string or a list of content parts for multimodal
  messages (text + images/files).

  ## Plain text message

      %Message{role: :user, content: "Hello"}

  ## Multimodal message (text + image)

      %Message{role: :user, content: [
        %{type: :text, content: "Describe this image"},
        %{type: :image, content: "base64...", media: :jpg}
      ]}

  Multimodal messages are built automatically by `LangchainPrompt.execute/4`
  when you pass `attachments`.
  """

  @enforce_keys [:role, :content]
  defstruct [:role, :content]

  @type content_part :: %{
          type: :text | :image | :file,
          content: String.t(),
          media: atom() | String.t() | nil
        }

  @type t :: %__MODULE__{
          role: :system | :user | :assistant,
          content: String.t() | [content_part()]
        }
end

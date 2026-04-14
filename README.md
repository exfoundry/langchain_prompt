# LangchainPrompt

A structured approach to building prompt-driven LLM pipelines in Elixir.

Define each AI task as a **prompt module** — a plain Elixir module that
implements a four-callback behaviour. `LangchainPrompt.execute/4` wires the
pieces together: builds the message list, calls the adapter, and runs
post-processing.

```elixir
defmodule MyApp.Prompts.Summarise do
  @behaviour LangchainPrompt.Prompt

  @impl true
  def set_profile(_assigns) do
    %LangchainPrompt.Profile{
      adapter: LangchainPrompt.Adapters.Langchain,
      opts: %{
        chat_module: LangChain.ChatModels.ChatOpenAI,
        model: "gpt-4o-mini"
      }
    }
  end

  @impl true
  def generate_system_prompt(_assigns), do: "You are a concise summariser."

  @impl true
  def generate_user_prompt(%{text: text}), do: "Summarise: #{text}"

  @impl true
  def post_process(_assigns, %LangchainPrompt.Message{content: content}),
    do: {:ok, content}
end

{:ok, summary} = LangchainPrompt.execute(MyApp.Prompts.Summarise, %{text: "..."})
```

## Installation

```elixir
def deps do
  [
    {:langchain_prompt, "~> 0.1"}
  ]
end
```

## Core concepts

### The `Prompt` behaviour

Each prompt module implements four callbacks:

| Callback | Returns | Purpose |
|---|---|---|
| `set_profile/1` | `Profile.t()` | Which adapter + model to use |
| `generate_system_prompt/1` | `String.t() \| nil` | The system message (nil to omit) |
| `generate_user_prompt/1` | `String.t() \| nil` | The user message (nil for conversation-tail) |
| `post_process/2` | `{:ok, any} \| {:error, any}` | Parse / validate the raw response |

`assigns` is whatever map or struct your application passes to `execute/4`. It
flows through every callback, so model selection, prompt content, and
post-processing can all be data-driven.

### Profiles

A `Profile` pairs an adapter module with its opts:

```elixir
%LangchainPrompt.Profile{
  adapter: LangchainPrompt.Adapters.Langchain,
  opts: %{
    chat_module: LangChain.ChatModels.ChatGoogleAI,
    model: "gemini-2.0-flash",
    temperature: 0.1
  }
}
```

For named profiles shared across many prompt modules, configure a profiles
module (see `LangchainPrompt.Profiles`).

### Message history

Pass prior turns as the third argument:

```elixir
history = [
  %LangchainPrompt.Message{role: :user, content: "Hello"},
  %LangchainPrompt.Message{role: :assistant, content: "Hi there!"}
]
LangchainPrompt.execute(MyPrompt, assigns, history)
```

Messages are assembled as: `[system] ++ history ++ [user]`.

### Attachments (multimodal)

```elixir
attachments = [LangchainPrompt.Attachment.from_file!("/tmp/menu.jpg")]
LangchainPrompt.execute(MyPrompt, assigns, [], attachments)
```

Supported file types: `.jpg`/`.jpeg`, `.png`, `.gif`, `.webp`, `.pdf`.

### Error handling

`execute/4` returns tagged error tuples:

- `{:error, {:adapter_failure, reason}}` — adapter returned an error
- `{:error, {:post_processing_failure, reason}}` — `post_process/2` returned an error

## Adapters

### `LangchainPrompt.Adapters.Langchain`

Delegates to any [elixir-langchain](https://hex.pm/packages/langchain) chat
model. Pass `:chat_module` in the profile opts:

```elixir
# Google AI
opts: %{chat_module: LangChain.ChatModels.ChatGoogleAI, model: "gemini-2.0-flash"}

# Anthropic
opts: %{chat_module: LangChain.ChatModels.ChatAnthropic, model: "claude-sonnet-4-6"}

# OpenAI-compatible (Deepseek, Mistral, Ollama, …)
opts: %{
  chat_module: LangChain.ChatModels.ChatOpenAI,
  model: "deepseek-chat",
  endpoint: "https://api.deepseek.com/chat/completions",
  api_key: System.get_env("DEEPSEEK_API_KEY")
}
```

### `LangchainPrompt.Adapters.Test`

Zero-dependency adapter for ExUnit. Records calls as process messages; use
`LangchainPrompt.TestAssertions` to assert on them.

**Trigger a failure:** include a message with content `"FAIL_NOW"`.

**Custom response:** pass `mock_content: "..."` in profile opts.

## Testing

```elixir
defmodule MyApp.Prompts.SummariseTest do
  use ExUnit.Case, async: true
  import LangchainPrompt.TestAssertions

  alias LangchainPrompt.Adapters.Test, as: TestAdapter
  alias LangchainPrompt.Profile

  # Override the profile to use the test adapter
  defmodule TestablePrompt do
    @behaviour LangchainPrompt.Prompt

    @impl true
    def set_profile(_), do: %Profile{adapter: TestAdapter, opts: %{}}

    defdelegate generate_system_prompt(a), to: MyApp.Prompts.Summarise
    defdelegate generate_user_prompt(a), to: MyApp.Prompts.Summarise
    defdelegate post_process(a, r), to: MyApp.Prompts.Summarise
  end

  test "builds the right user prompt" do
    LangchainPrompt.execute(TestablePrompt, %{text: "hello world"})

    assert_adapter_called(fn payload ->
      user_msg = List.last(payload.messages)
      assert user_msg.content =~ "hello world"
    end)
  end
end
```

Or configure the test adapter globally via `LangchainPrompt.Profiles.TestImpl`:

```elixir
# config/test.exs
config :langchain_prompt, :profiles_impl, LangchainPrompt.Profiles.TestImpl
```

## Named profiles

```elixir
# lib/my_app/ai_profiles.ex
defmodule MyApp.AIProfiles do
  alias LangchainPrompt.{Profile, Adapters.Langchain}

  def get(:fast) do
    %Profile{
      adapter: Langchain,
      opts: %{chat_module: LangChain.ChatModels.ChatGoogleAI, model: "gemini-2.0-flash-lite"}
    }
  end

  def get(:smart) do
    %Profile{
      adapter: Langchain,
      opts: %{chat_module: LangChain.ChatModels.ChatAnthropic, model: "claude-opus-4-6"}
    }
  end
end

# config/config.exs
config :langchain_prompt, :profiles_impl, MyApp.AIProfiles

# config/test.exs
config :langchain_prompt, :profiles_impl, LangchainPrompt.Profiles.TestImpl
```

Then in a prompt module:

```elixir
def set_profile(_assigns), do: LangchainPrompt.Profiles.get(:fast)
```

## License

MIT

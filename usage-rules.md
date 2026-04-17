# langchain_prompt usage rules

Rules apply to `langchain_prompt ~> 0.1.1`.

Opinionated prompt-module architecture. A prompt module bundles model
choice, system/user prompts, and response parsing into one file. Execute
it with `LangchainPrompt.execute/4`. Test it with a built-in test adapter.

## Minimal pattern

```elixir
defmodule MyApp.Prompts.Classify do
  @behaviour LangchainPrompt.Prompt

  alias LangchainPrompt.Message
  alias LangchainPrompt.Profile
  alias LangchainPrompt.Adapters.Langchain

  @impl true
  def set_profile(_assigns) do
    %Profile{
      adapter: Langchain,
      opts: %{chat_module: LangChain.ChatModels.ChatOpenAI, model: "gpt-4o-mini"}
    }
  end

  @impl true
  def generate_system_prompt(_assigns), do: "Classify sentiment. Reply one word."

  @impl true
  def generate_user_prompt(%{text: text}), do: text

  @impl true
  def post_process(_assigns, %Message{content: content}) do
    case String.trim(content) do
      "positive" -> {:ok, :positive}
      "neutral"  -> {:ok, :neutral}
      "negative" -> {:ok, :negative}
      other      -> {:error, {:unexpected_response, other}}
    end
  end
end

{:ok, :positive} = LangchainPrompt.execute(MyApp.Prompts.Classify, %{text: "great!"})
```

## Required callbacks

All four are mandatory when you `@behaviour LangchainPrompt.Prompt`.

| Callback | Signature | Purpose |
|---|---|---|
| `set_profile/1` | `(assigns) -> %Profile{}` | Pick adapter + model opts |
| `generate_system_prompt/1` | `(assigns) -> String.t \| nil` | `nil` omits system msg |
| `generate_user_prompt/1` | `(assigns) -> String.t \| nil` | `nil` for conversational prompts |
| `post_process/2` | `(assigns, %Message{}) -> {:ok, any} \| {:error, any}` | Parse raw LLM output |

`assigns` is whatever you pass to `execute/4` — a map or struct, your choice.

## The single entry point

```elixir
LangchainPrompt.execute(prompt_module, assigns, message_history \\ [], attachments \\ [])
```

Returns `{:ok, result}` or `{:error, reason}`. Error reasons are always
tagged tuples:

- `{:adapter_failure, reason}` — LLM call failed
- `{:post_processing_failure, reason}` — your `post_process/2` returned `{:error, _}`
- `{:unknown_failure, _}` — anything else (shouldn't happen in practice)

**Always pattern-match on these tags.** Never rescue `{:error, _}` without
inspecting the tag — it hides real bugs in `post_process/2`.

```elixir
case LangchainPrompt.execute(ExtractAisc, %{text: document.text}) do
  {:ok, data} -> process(data)
  {:error, {:adapter_failure, reason}} -> log_error(reason)
  {:error, {:post_processing_failure, :invalid_json}} -> retry()
end
```

## Profiles (named model configurations)

When several prompts share a model config, extract it:

```elixir
defmodule MyApp.AIProfiles do
  alias LangchainPrompt.Profile
  alias LangchainPrompt.Adapters.Langchain

  def get(:fast) do
    %Profile{adapter: Langchain, opts: %{chat_module: LangChain.ChatModels.ChatGoogleAI, model: "gemini-2.0-flash-lite"}}
  end

  def get(:smart) do
    %Profile{adapter: Langchain, opts: %{chat_module: LangChain.ChatModels.ChatOpenAI, model: "gpt-4o"}}
  end
end
```

Wire it up once:

```elixir
# config/config.exs
config :langchain_prompt, :profiles_impl, MyApp.AIProfiles

# config/test.exs — swap to test adapter
config :langchain_prompt, :profiles_impl, MyApp.AIProfiles.Test
```

Then in prompt modules:

```elixir
def set_profile(_assigns), do: LangchainPrompt.Profiles.get(:fast)
```

## Testing

The `LangchainPrompt.Adapters.Test` adapter runs in-process, never calls
an external API, and records every invocation as a message to the
caller. In `config/test.exs`, swap every profile's adapter to this one.

**`async: true` is safe by default** — the test adapter routes
invocations via `self()` and `$callers`, so there's no shared state
between tests.

```elixir
# config/test.exs
defmodule MyApp.AIProfiles.Test do
  alias LangchainPrompt.Profile
  alias LangchainPrompt.Adapters.Test

  def get(_name), do: %Profile{adapter: Test, opts: %{mock_content: "mocked response"}}
end
```

```elixir
use ExUnit.Case
import LangchainPrompt.TestAssertions

test "sends the right system prompt" do
  LangchainPrompt.execute(MyApp.Prompts.Classify, %{text: "hi"})

  assert_adapter_called(fn payload ->
    [sys | _] = payload.messages
    assert sys.role == :system
    assert sys.content =~ "Classify"
  end)
end

test "handles adapter errors" do
  # The string "FAIL_NOW" in any message triggers an adapter failure
  assert {:error, {:adapter_failure, :adapter_did_fail_on_demand}} =
           LangchainPrompt.execute(MyApp.Prompts.Classify, %{text: "FAIL_NOW"})
end
```

**`mock_content`** controls what the test adapter returns. Set it in the
profile opts to drive `post_process/2` down specific branches.

**`"FAIL_NOW"`** in any message content forces `{:error, :adapter_did_fail_on_demand}`
without any response — use it to exercise error paths.

For async tests that spawn work across processes, pin the destination:

```elixir
Application.put_env(:langchain_prompt, :test_process, self())
```

## Message history & attachments

Conversational prompts pass prior turns as the third argument. Set
`generate_user_prompt/1` to return `nil` when the new user message is
already in the history:

```elixir
history = [
  %LangchainPrompt.Message{role: :user, content: "Hello"},
  %LangchainPrompt.Message{role: :assistant, content: "Hi!"},
  %LangchainPrompt.Message{role: :user, content: "How are you?"}
]

LangchainPrompt.execute(MyPrompt, assigns, history)
```

Attachments (images, files) as the fourth argument:

```elixir
attachments = [LangchainPrompt.Attachment.from_file!("/tmp/menu.jpg")]
LangchainPrompt.execute(VisionPrompt, assigns, [], attachments)
```

## Do

- **One prompt module per AI task.** Don't branch on `assigns` to do
  fundamentally different things — split into two modules.
- **Keep `post_process/2` total.** Every LLM output shape should land in
  `{:ok, _}` or `{:error, _}`. Don't raise.
- **Use profiles** the moment two prompts share the same adapter opts.
- **Test with `LangchainPrompt.Adapters.Test`** — never hit real APIs in
  unit tests. Use it to assert on the exact messages your prompt sends.
- **Match on `{:error, {:adapter_failure, _}}` and
  `{:error, {:post_processing_failure, _}}` separately.** They mean
  different things (API down vs. your parser is wrong).

## Don't

- **Don't call the `Langchain` adapter directly.** Go through
  `LangchainPrompt.execute/4` so post-processing, profiles, and error
  tagging are consistent.
- **Don't stash mutable state in prompt modules.** They're stateless
  behaviours — all state flows through `assigns`.
- **Don't return raw strings from `post_process/2`.** Always
  `{:ok, value}` / `{:error, reason}` — the executor unwraps them.
- **Don't hard-code model names in prompt modules** once you have
  profiles. Switching model = editing one file, not ten.
- **Don't forget `config :langchain_prompt, :profiles_impl, ...`** —
  calling `LangchainPrompt.Profiles.get/1` without it raises with a
  clear ArgumentError, but only at runtime.
- **Don't add profiles speculatively.** Extract a profile only when two
  prompts genuinely share the same adapter opts, not in anticipation of
  future sharing. One profile for all current prompts is fine.

## Configuration

| Key | Purpose |
|---|---|
| `config :langchain_prompt, :profiles_impl, Module` | Named-profile resolver (required only if you use `Profiles.get/1`) |
| `Application.put_env(:langchain_prompt, :test_process, pid)` | Pin test-adapter message target for async/cross-process tests |

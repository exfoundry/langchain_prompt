defmodule LangchainPrompt.Adapters.Test do
  @moduledoc """
  In-process adapter for ExUnit tests.

  Records every `chat/2` call by sending a `{:adapter_called, payload}` message
  to the calling process (and any `$callers`). Use `LangchainPrompt.TestAssertions`
  to assert on these messages.

  ## On-demand failure

  Any message whose `content` is the string `"FAIL_NOW"` causes the adapter to
  return `{:error, :adapter_did_fail_on_demand}` without sending any message.

  ## Shared process override

  For async tests that spawn work in separate processes, set:

      Application.put_env(:langchain_prompt, :test_process, self())

  The adapter will send the `:adapter_called` message to that PID instead of
  walking `$callers`.

  ## Mock response content

  Pass `mock_content: "custom response"` in profile opts to control what the
  adapter returns.
  """

  @behaviour LangchainPrompt.Adapter

  @impl true
  def chat(messages, opts) do
    if Enum.any?(messages, &(&1.content == "FAIL_NOW")) do
      {:error, :adapter_did_fail_on_demand}
    else
      for pid <- pids() do
        send(pid, {:adapter_called, %{messages: messages, opts: opts}})
      end

      content = Map.get(opts, :mock_content, "mocked response")

      {:ok, %LangchainPrompt.Message{role: :assistant, content: content}}
    end
  end

  defp pids do
    if pid = Application.get_env(:langchain_prompt, :test_process) do
      [pid]
    else
      Enum.uniq([self() | List.wrap(Process.get(:"$callers"))])
    end
  end
end

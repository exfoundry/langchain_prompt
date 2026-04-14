defmodule LangchainPrompt.TestAssertions do
  @moduledoc """
  ExUnit helpers for asserting on `LangchainPrompt.Adapters.Test` calls.

  Import this in your test files:

      import LangchainPrompt.TestAssertions

  ## Macros

  - `assert_adapter_called/0` — asserts the adapter was called (ignores payload).
  - `assert_adapter_called/1` — asserts the adapter was called and runs an
    assertion function on the payload.
  - `refute_adapter_called/0` — asserts the adapter was NOT called.

  ## Example

      test "sends the right system prompt" do
        LangchainPrompt.execute(MyPrompt, assigns)

        assert_adapter_called(fn payload ->
          system_msg = hd(payload.messages)
          assert system_msg.role == :system
          assert system_msg.content =~ "summarise"
        end)
      end
  """

  import ExUnit.Assertions

  @doc """
  Asserts the test adapter was called, and optionally inspects the payload.

  When called with a function, the function receives a map with:
  - `:messages` — the list of `LangchainPrompt.Message` structs sent to the adapter
  - `:opts` — the profile opts map
  """
  defmacro assert_adapter_called(filter \\ nil) do
    if filter do
      quote do
        assert_received {:adapter_called, payload}
        unquote(__MODULE__).run_filter(payload, unquote(filter))
      end
    else
      quote do
        assert_received {:adapter_called, _payload}
      end
    end
  end

  @doc """
  Asserts the test adapter was NOT called.
  """
  defmacro refute_adapter_called do
    quote do
      refute_received {:adapter_called, _}
    end
  end

  @doc false
  def run_filter(payload, fun) when is_function(fun, 1) do
    fun.(payload)
  end
end

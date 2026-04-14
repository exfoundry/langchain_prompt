defmodule LangchainPrompt.Profiles.TestImpl do
  @moduledoc """
  Test implementation of `LangchainPrompt.Profiles`. Always returns the
  `LangchainPrompt.Adapters.Test` adapter, so no real LLM calls are made.

  Configure in `config/test.exs`:

      config :langchain_prompt, :profiles_impl, LangchainPrompt.Profiles.TestImpl
  """

  alias LangchainPrompt.Adapters.Test, as: TestAdapter
  alias LangchainPrompt.Profile

  def get(_profile_name) do
    %Profile{adapter: TestAdapter, opts: %{test_profile: true}}
  end
end

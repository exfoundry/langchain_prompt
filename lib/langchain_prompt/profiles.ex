defmodule LangchainPrompt.Profiles do
  @moduledoc """
  Indirection layer for named AI execution profiles.

  Delegates `get/1` to the module configured under
  `config :langchain_prompt, :profiles_impl, MyApp.AIProfiles`.

  This allows applications to define their own named profiles without
  coupling prompt modules to a concrete profile module.

  ## Setup

  1. Create a module that implements `get/1`:

         defmodule MyApp.AIProfiles do
           alias LangchainPrompt.Profile
           alias LangchainPrompt.Adapters.Langchain

           def get(:fast) do
             %Profile{
               adapter: Langchain,
               opts: %{chat_module: LangChain.ChatModels.ChatGoogleAI, model: "gemini-2.0-flash-lite"}
             }
           end
         end

  2. Configure it:

         # config/config.exs
         config :langchain_prompt, :profiles_impl, MyApp.AIProfiles

         # config/test.exs
         config :langchain_prompt, :profiles_impl, LangchainPrompt.Profiles.TestImpl

  3. Use it in prompt modules:

         def set_profile(_assigns), do: LangchainPrompt.Profiles.get(:fast)
  """

  @doc "Returns a `Profile` for the given name, delegating to the configured implementation."
  def get(profile_name) do
    impl =
      Application.get_env(:langchain_prompt, :profiles_impl) ||
        raise ArgumentError,
              "config :langchain_prompt, :profiles_impl is not set. " <>
                "Add it to your config (e.g. config :langchain_prompt, :profiles_impl, MyApp.AIProfiles)."

    impl.get(profile_name)
  end
end

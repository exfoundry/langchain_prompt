# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-04-17

### Changed

- `usage-rules.md` — added concrete multi-clause error-handling example at
  the call site, `async: true` safety note in the Testing section, and a
  Don't entry discouraging speculative profile extraction.

## [0.1.0] - 2026-04-13

### Added

- `LangchainPrompt.execute/4` — runs a prompt module against an adapter,
  returning `{:ok, result}` or a tagged `{:error, reason}` tuple.
- `LangchainPrompt.Prompt` behaviour — four-callback contract (`set_profile/1`,
  `generate_system_prompt/1`, `generate_user_prompt/1`, `post_process/2`).
- `LangchainPrompt.Adapter` behaviour — single-callback contract (`chat/2`)
  for plugging in any LLM provider.
- `LangchainPrompt.Profile` struct — pairs an adapter module with its runtime opts.
- `LangchainPrompt.Message` struct — represents a single conversation turn,
  supporting plain string content and multimodal content-part lists.
- `LangchainPrompt.Attachment` struct + `from_file!/1` — adapter-agnostic
  container for binary file data (images, PDFs); infers type and media from
  file extension.
- `LangchainPrompt.Adapters.Langchain` — delegates to any
  [elixir-langchain](https://hex.pm/packages/langchain) chat model via
  `:chat_module` in the profile opts. Handles both plain-string and
  ContentPart-list responses (covers Google AI, Anthropic, OpenAI, Deepseek,
  and more).
- `LangchainPrompt.Adapters.Test` — zero-dependency ExUnit adapter; records
  calls as process messages, supports on-demand failure via `"FAIL_NOW"` sentinel.
- `LangchainPrompt.TestAssertions` — `assert_adapter_called/0`,
  `assert_adapter_called/1`, `refute_adapter_called/0` macros for ExUnit.
- `LangchainPrompt.Profiles` — configurable indirection layer for named
  execution profiles (`config :langchain_prompt, :profiles_impl, MyModule`).
- `LangchainPrompt.Profiles.TestImpl` — test implementation that always
  returns the `Test` adapter.

[Unreleased]: https://github.com/exfoundry/langchain_prompt/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/exfoundry/langchain_prompt/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/exfoundry/langchain_prompt/releases/tag/v0.1.0

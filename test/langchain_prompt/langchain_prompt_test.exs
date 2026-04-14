defmodule LangchainPromptTest do
  use ExUnit.Case, async: true

  import LangchainPrompt.TestAssertions

  alias LangchainPrompt
  alias LangchainPrompt.{Attachment, Message, Prompt}
  alias LangchainPrompt.Profile
  alias LangchainPrompt.Adapters.Test, as: TestAdapter

  defmodule TestPrompt do
    @behaviour Prompt

    @impl Prompt
    def set_profile(assigns) do
      opts = Map.get(assigns, :adapter_opts, %{})
      %Profile{adapter: TestAdapter, opts: opts}
    end

    @impl Prompt
    def generate_system_prompt(assigns), do: Map.get(assigns, :system_prompt)

    @impl Prompt
    def generate_user_prompt(assigns), do: Map.get(assigns, :user_prompt)

    @impl Prompt
    def post_process(assigns, _raw_response) do
      Map.get(assigns, :post_process_return, {:ok, "default success"})
    end
  end

  describe "execute/3" do
    test "correctly assembles messages and calls the adapter" do
      assigns = %{system_prompt: "system test", user_prompt: "user test"}
      history = [%Message{role: :user, content: "history test"}]

      assert {:ok, "default success"} = LangchainPrompt.execute(TestPrompt, assigns, history)

      assert_adapter_called(fn payload ->
        message_contents = Enum.map(payload.messages, & &1.content)
        assert message_contents == ["system test", "history test", "user test"]
      end)
    end

    test "omits system message when generate_system_prompt returns nil" do
      assigns = %{system_prompt: nil, user_prompt: "hello"}

      assert {:ok, _} = LangchainPrompt.execute(TestPrompt, assigns)

      assert_adapter_called(fn payload ->
        assert length(payload.messages) == 1
        assert hd(payload.messages).role == :user
      end)
    end

    test "omits user message when generate_user_prompt returns nil (conversational AI)" do
      assigns = %{system_prompt: "system context", user_prompt: nil}
      history = [%Message{role: :user, content: "the last user message in history"}]

      assert {:ok, "default success"} = LangchainPrompt.execute(TestPrompt, assigns, history)

      assert_adapter_called(fn payload ->
        message_contents = Enum.map(payload.messages, & &1.content)
        assert message_contents == ["system context", "the last user message in history"]
      end)
    end

    test "preserves message order: system → history → user" do
      assigns = %{system_prompt: "sys", user_prompt: "usr"}

      history = [
        %Message{role: :user, content: "turn 1"},
        %Message{role: :assistant, content: "reply 1"}
      ]

      assert {:ok, _} = LangchainPrompt.execute(TestPrompt, assigns, history)

      assert_adapter_called(fn payload ->
        roles = Enum.map(payload.messages, & &1.role)
        assert roles == [:system, :user, :assistant, :user]
      end)
    end

    test "returns {:error, {:adapter_failure, reason}} when the adapter fails" do
      assigns = %{system_prompt: "any", user_prompt: "FAIL_NOW"}

      assert {:error, {:adapter_failure, :adapter_did_fail_on_demand}} =
               LangchainPrompt.execute(TestPrompt, assigns)

      refute_adapter_called()
    end

    test "returns {:error, {:post_processing_failure, reason}} when post_process fails" do
      assigns = %{post_process_return: {:error, :post_processing_did_fail}}

      assert {:error, {:post_processing_failure, :post_processing_did_fail}} =
               LangchainPrompt.execute(TestPrompt, assigns)

      assert_adapter_called()
    end

    test "passes profile opts to the adapter" do
      assigns = %{adapter_opts: %{mock_content: "custom"}, user_prompt: "hi"}

      assert {:ok, _} = LangchainPrompt.execute(TestPrompt, assigns)

      assert_adapter_called(fn payload ->
        assert payload.opts == %{mock_content: "custom"}
      end)
    end
  end

  describe "execute/4 with attachments" do
    test "builds a multimodal user message with text and image attachment" do
      assigns = %{system_prompt: "system", user_prompt: "describe this"}

      attachments = [%Attachment{type: :image, content: "base64data", media: :jpg}]

      assert {:ok, _} = LangchainPrompt.execute(TestPrompt, assigns, [], attachments)

      assert_adapter_called(fn payload ->
        user_msg = List.last(payload.messages)
        assert is_list(user_msg.content)

        assert [
                 %{type: :text, content: "describe this"},
                 %{type: :image, content: "base64data", media: :jpg}
               ] = user_msg.content
      end)
    end

    test "keeps plain string content when attachments list is empty" do
      assigns = %{user_prompt: "just text"}

      assert {:ok, _} = LangchainPrompt.execute(TestPrompt, assigns, [], [])

      assert_adapter_called(fn payload ->
        user_msg = List.last(payload.messages)
        assert user_msg.content == "just text"
      end)
    end

    test "supports multiple attachments" do
      assigns = %{user_prompt: "extract menu"}

      attachments = [
        %Attachment{type: :image, content: "page1", media: :png},
        %Attachment{type: :image, content: "page2", media: :png}
      ]

      assert {:ok, _} = LangchainPrompt.execute(TestPrompt, assigns, [], attachments)

      assert_adapter_called(fn payload ->
        user_msg = List.last(payload.messages)
        # 1 text + 2 images
        assert length(user_msg.content) == 3
      end)
    end
  end

  describe "Attachment.from_file!/1" do
    test "reads a jpg file and creates an image attachment" do
      path = Path.join(System.tmp_dir!(), "lp_test_attachment.jpg")
      File.write!(path, "fake image data")

      attachment = Attachment.from_file!(path)

      assert attachment.type == :image
      assert attachment.media == :jpg
      assert attachment.content == Base.encode64("fake image data")
    after
      File.rm(Path.join(System.tmp_dir!(), "lp_test_attachment.jpg"))
    end

    test "treats .jpeg as :jpg" do
      path = Path.join(System.tmp_dir!(), "lp_test_attachment.jpeg")
      File.write!(path, "data")

      attachment = Attachment.from_file!(path)

      assert attachment.media == :jpg
    after
      File.rm(Path.join(System.tmp_dir!(), "lp_test_attachment.jpeg"))
    end

    test "reads a PDF file as :file type" do
      path = Path.join(System.tmp_dir!(), "lp_test_attachment.pdf")
      File.write!(path, "fake pdf data")

      attachment = Attachment.from_file!(path)

      assert attachment.type == :file
      assert attachment.media == :pdf
    after
      File.rm(Path.join(System.tmp_dir!(), "lp_test_attachment.pdf"))
    end

    test "raises ArgumentError on unsupported extension" do
      path = Path.join(System.tmp_dir!(), "lp_test_attachment.xyz")
      File.write!(path, "data")

      assert_raise ArgumentError, ~r/unsupported file extension/, fn ->
        Attachment.from_file!(path)
      end
    after
      File.rm(Path.join(System.tmp_dir!(), "lp_test_attachment.xyz"))
    end
  end
end

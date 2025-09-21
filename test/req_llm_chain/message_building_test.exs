defmodule ReqLLMChain.MessageBuildingTest do
  use ExUnit.Case

  describe "message building" do
    test "adds system messages" do
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are helpful")

      messages = ReqLLMChain.messages(chain)
      assert length(messages) == 1
      assert List.first(messages).role == :system
    end

    test "adds user messages" do
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.user("Hello")

      messages = ReqLLMChain.messages(chain)
      assert length(messages) == 1
      assert List.first(messages).role == :user
    end

    test "adds assistant messages" do
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.assistant("Hi there!")

      messages = ReqLLMChain.messages(chain)
      assert length(messages) == 1
      assert List.first(messages).role == :assistant
    end

    test "builds multi-turn conversation" do
      chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.system("You are helpful")
        |> ReqLLMChain.user("Hello")
        |> ReqLLMChain.assistant("Hi!")
        |> ReqLLMChain.user("How are you?")

      messages = ReqLLMChain.messages(chain)
      assert length(messages) == 4

      roles = Enum.map(messages, & &1.role)
      assert roles == [:system, :user, :assistant, :user]
    end

    test "preserves message order in complex conversations" do
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are a helpful assistant")
        |> ReqLLMChain.user("What's 2+2?")
        |> ReqLLMChain.assistant("2+2 equals 4")
        |> ReqLLMChain.user("What about 3+3?")
        |> ReqLLMChain.assistant("3+3 equals 6")

      messages = ReqLLMChain.messages(chain)
      roles = Enum.map(messages, & &1.role)

      assert roles == [:system, :user, :assistant, :user, :assistant]
      # Check that the conversation text contains our expected phrases
      text_content = ReqLLMChain.text_content(chain)
      assert text_content =~ "2+2"
      assert text_content =~ "3+3"
    end

    test "text_content extraction works for all message types" do
      chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.system("System message")
        |> ReqLLMChain.user("User message")
        |> ReqLLMChain.assistant("Assistant message")

      text_content = ReqLLMChain.text_content(chain)

      assert text_content =~ "System message"
      assert text_content =~ "User message"
      assert text_content =~ "Assistant message"
    end
  end

  describe "message validation and edge cases" do
    test "handles empty string messages" do
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("")
        |> ReqLLMChain.user("")

      messages = ReqLLMChain.messages(chain)
      assert length(messages) == 2

      # Check that the chain can handle empty messages without error
      # The actual structure is maintained even with empty content
      assert Enum.all?(messages, fn msg ->
        is_binary(msg.content) or is_list(msg.content)
      end)
    end

    test "handles unicode and special characters" do
      unicode_content = "Hello 🌍! This is a test with émojis and spëcial chars: 你好"

      chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.user(unicode_content)

      # Check that the message properly contains the unicode content
      # Use text_content to extract the actual text
      text_content = ReqLLMChain.text_content(chain)
      assert text_content =~ "Hello 🌍!"
      assert text_content =~ "你好"
    end
  end
end

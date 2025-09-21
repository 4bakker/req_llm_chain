defmodule ReqLLMChainTest do
  use ExUnit.Case
  doctest ReqLLMChain

  alias ReqLLMChain.Chain

  describe "chain creation" do
    test "creates a new chain with string model spec" do
      chain = ReqLLMChain.new("anthropic:claude-3-sonnet")

      assert %Chain{} = chain
      assert chain.model.provider == :anthropic
      assert chain.model.model == "claude-3-sonnet"
      assert chain.context.messages == []
      assert chain.tools == []
      assert chain.custom_context == %{}
    end

    test "creates a chain with options" do
      chain = ReqLLMChain.new("openai:gpt-4", temperature: 0.7, max_tokens: 1000)

      assert chain.model.provider == :openai
      assert chain.options == [temperature: 0.7, max_tokens: 1000]
    end
  end

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
  end

  describe "tools and context" do
    test "adds tools to chain" do
      tool = create_test_tool()

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.tools([tool])

      assert length(chain.tools) == 1
      assert List.first(chain.tools).name == "test_tool"
    end

    test "adds custom context" do
      custom_context = %{user_id: 123, api_key: "test"}

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.context(custom_context)

      assert chain.custom_context == custom_context
    end

    test "combines tools and context" do
      tool = create_test_tool()
      custom_context = %{user_id: 123}

      chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.system("You are helpful")
        |> ReqLLMChain.tools([tool])
        |> ReqLLMChain.context(custom_context)

      assert length(chain.tools) == 1
      assert chain.custom_context == custom_context
      assert length(ReqLLMChain.messages(chain)) == 1
    end
  end

  describe "text extraction" do
    test "extracts text content from conversation" do
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are a helpful assistant")
        |> ReqLLMChain.user("What's 2+2?")
        |> ReqLLMChain.assistant("2+2 equals 4")

      text = ReqLLMChain.text_content(chain)

      assert text =~ "[SYSTEM] You are a helpful assistant"
      assert text =~ "[USER] What's 2+2?"
      assert text =~ "[ASSISTANT] 2+2 equals 4"
    end

    test "handles empty conversation" do
      chain = ReqLLMChain.new("openai:gpt-4")
      text = ReqLLMChain.text_content(chain)

      assert text == ""
    end
  end

  describe "builder pattern immutability" do
    test "chain operations return new chains" do
      original_chain = ReqLLMChain.new("openai:gpt-4")
      updated_chain = ReqLLMChain.system(original_chain, "You are helpful")

      # Original chain unchanged
      assert length(ReqLLMChain.messages(original_chain)) == 0

      # New chain has the message
      assert length(ReqLLMChain.messages(updated_chain)) == 1
    end

    test "chains can be built step by step" do
      chain1 = ReqLLMChain.new("anthropic:claude-3-sonnet")
      chain2 = ReqLLMChain.system(chain1, "System message")
      chain3 = ReqLLMChain.user(chain2, "User message")
      chain4 = ReqLLMChain.tools(chain3, [create_test_tool()])

      assert length(ReqLLMChain.messages(chain1)) == 0
      assert length(ReqLLMChain.messages(chain2)) == 1
      assert length(ReqLLMChain.messages(chain3)) == 2
      assert length(ReqLLMChain.messages(chain4)) == 2
      assert length(chain4.tools) == 1
    end
  end

  # Helper functions
  defp create_test_tool do
    ReqLLM.Tool.new!(
      name: "test_tool",
      description: "A test tool",
      parameter_schema: [
        input: [type: :string, required: true]
      ],
      callback: fn params, _context ->
        {:ok, "Test result for: #{params["input"]}"}
      end
    )
  end
end

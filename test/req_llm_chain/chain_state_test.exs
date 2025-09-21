defmodule ReqLLMChain.ChainStateTest do
  use ExUnit.Case

  import ReqLLMChain.TestHelpers

  describe "chain state and immutability" do
    test "chain operations are immutable" do
      original_chain = ReqLLMChain.new("anthropic:claude-3-sonnet")

      chain_with_message = ReqLLMChain.user(original_chain, "Hello")
      chain_with_tool = ReqLLMChain.tools(original_chain, [create_test_tool()])
      chain_with_context = ReqLLMChain.context(original_chain, %{key: "value"})

      # Original chain should be unchanged
      assert ReqLLMChain.messages(original_chain) == []
      assert original_chain.tools == []
      assert original_chain.custom_context == %{}

      # New chains should have changes
      assert length(ReqLLMChain.messages(chain_with_message)) == 1
      assert length(chain_with_tool.tools) == 1
      assert chain_with_context.custom_context == %{key: "value"}
    end

    test "chaining operations preserves intermediate state" do
      tool1 = create_tool("tool1", "First tool")
      tool2 = create_tool("tool2", "Second tool")

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are helpful")
        |> ReqLLMChain.tools([tool1])
        |> ReqLLMChain.user("Hello")
        |> ReqLLMChain.tools([tool2])  # Should add to existing tools
        |> ReqLLMChain.context(%{session_id: "123"})

      messages = ReqLLMChain.messages(chain)
      assert length(messages) == 2
      assert length(chain.tools) == 2
      assert chain.custom_context.session_id == "123"

      # Verify message order
      [system_msg, user_msg] = messages
      assert system_msg.role == :system
      assert user_msg.role == :user
    end

    test "chain can be built step by step" do
      step1 = ReqLLMChain.new("anthropic:claude-3-sonnet")
      step2 = ReqLLMChain.system(step1, "System prompt")
      step3 = ReqLLMChain.user(step2, "User message")
      step4 = ReqLLMChain.tools(step3, [create_test_tool()])
      step5 = ReqLLMChain.context(step4, %{step: 5})

      # Each step should be distinct
      assert ReqLLMChain.messages(step1) == []
      assert length(ReqLLMChain.messages(step2)) == 1
      assert length(ReqLLMChain.messages(step3)) == 2
      assert length(step4.tools) == 1
      assert step5.custom_context.step == 5
    end

    test "builder pattern immutability" do
      # Create base chain
      base_chain = ReqLLMChain.new("openai:gpt-4")

      # Create variations without affecting the base
      chain1 = ReqLLMChain.system(base_chain, "Assistant 1")
      chain2 = ReqLLMChain.system(base_chain, "Assistant 2")
      chain3 = ReqLLMChain.user(base_chain, "User input")
      chain4 = ReqLLMChain.tools(base_chain, [create_test_tool()])

      # Base should be unchanged
      assert ReqLLMChain.messages(base_chain) == []
      assert base_chain.tools == []

      # Each variation should be independent
      assert length(ReqLLMChain.messages(chain1)) == 1
      assert length(ReqLLMChain.messages(chain2)) == 1
      assert length(ReqLLMChain.messages(chain3)) == 1
      assert length(ReqLLMChain.messages(chain4)) == 0

      # But chain4 should have tools
      assert length(chain4.tools) == 1

      # Different system messages
      [msg1] = ReqLLMChain.messages(chain1)
      [msg2] = ReqLLMChain.messages(chain2)
      assert msg1.content != msg2.content
    end

    test "deep chain modifications preserve structure" do
      initial_context = %{
        user: %{id: 123, name: "Alice"},
        session: %{id: "abc", tools: ["calculator"]}
      }

      chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.context(initial_context)
        |> ReqLLMChain.system("System message")
        |> ReqLLMChain.user("User message")

      # Adding more context should merge properly
      additional_context = %{
        user: %{preferences: %{theme: "dark"}},
        api_keys: %{openai: "key123"}
      }

      updated_chain = ReqLLMChain.context(chain, additional_context)

      # Original chain context should be preserved
      assert chain.custom_context.user.name == "Alice"
      assert chain.custom_context.session.id == "abc"

      # Updated chain should have merged context
      assert updated_chain.custom_context.user.preferences.theme == "dark"
      assert updated_chain.custom_context.api_keys.openai == "key123"
      # But original values should still be there (deep merge behavior)
      assert updated_chain.custom_context.session.id == "abc"
    end
  end
end

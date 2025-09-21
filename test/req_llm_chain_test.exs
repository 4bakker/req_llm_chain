defmodule ReqLLMChainTest do
  use ExUnit.Case
  doctest ReqLLMChain

  import ReqLLMChain.TestHelpers

  describe "high-level integration tests" do
    test "complete builder pattern workflow" do
      # Test the complete workflow from creation to execution-ready state
      chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.system("You are a helpful assistant")
        |> ReqLLMChain.tools([create_calculator_tool(), create_weather_tool()])
        |> ReqLLMChain.context(%{user_id: "test_123", session: "abc"})
        |> ReqLLMChain.user("What's 2+2 and what's the weather?")
        |> ReqLLMChain.assistant("I'll help you with both calculations and weather.")

      # Verify complete state
      assert length(ReqLLMChain.messages(chain)) == 3
      assert length(chain.tools) == 2
      assert chain.custom_context.user_id == "test_123"

      # Verify message flow
      messages = ReqLLMChain.messages(chain)
      [system_msg, user_msg, assistant_msg] = messages
      assert system_msg.role == :system
      assert user_msg.role == :user
      assert assistant_msg.role == :assistant

      # Verify tools are available
      tool_names = Enum.map(chain.tools, & &1.name)
      assert "calculator" in tool_names
      assert "weather" in tool_names

      # Verify text extraction works across all messages
      text_content = ReqLLMChain.text_content(chain)
      assert text_content =~ "helpful assistant"
      assert text_content =~ "2+2"
      assert text_content =~ "weather"
    end

    test "cross-module functionality" do
      # Test that all modules work together seamlessly
      base_chain = ReqLLMChain.new("openai:gpt-4")

      # Add components from different modules
      chain_with_messages =
        base_chain
        |> ReqLLMChain.system("System prompt")
        |> ReqLLMChain.user("User input")

      chain_with_tools =
        chain_with_messages
        |> ReqLLMChain.tools([create_test_tool()])

      final_chain =
        chain_with_tools
        |> ReqLLMChain.context(%{integration: "test"})
        |> ReqLLMChain.assistant("Assistant response")

      # Verify all components are integrated
      assert length(ReqLLMChain.messages(final_chain)) == 3
      assert length(final_chain.tools) == 1
      assert final_chain.custom_context.integration == "test"
      assert final_chain.model.provider == :openai
    end
  end
end

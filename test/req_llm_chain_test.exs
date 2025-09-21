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

  describe "error handling and validation" do
    test "handles invalid model spec gracefully" do
      assert_raise ReqLLM.Error.Validation.Error, fn ->
        ReqLLMChain.new("invalid:model:spec:format")
      end
    end

    test "validates required parameters for tools" do
      invalid_tool = fn ->
        ReqLLM.Tool.new!(
          # Missing required name
          description: "A test tool",
          parameter_schema: [],
          callback: fn _params -> {:ok, "result"} end
        )
      end

      assert_raise ReqLLM.Error.Validation.Error, invalid_tool
    end

    test "handles empty messages gracefully" do
      chain = ReqLLMChain.new("openai:gpt-4")
      assert chain.context.messages == []
      assert ReqLLMChain.messages(chain) == []
    end

    test "validates tool execution failures" do
      failing_tool = ReqLLM.Tool.new!(
        name: "failing_tool",
        description: "A tool that fails",
        parameter_schema: [
          input: [type: :string, required: true]
        ],
        callback: fn _params ->
          {:error, "Tool execution failed"}
        end
      )

      # Tool creation should succeed even if callback will fail
      assert failing_tool.name == "failing_tool"
    end
  end

  describe "complex tool calling scenarios" do
    test "handles multiple tool execution" do
      calculator_tool = ReqLLM.Tool.new!(
        name: "calculator",
        description: "Basic calculator",
        parameter_schema: [
          expression: [type: :string, required: true]
        ],
        callback: fn %{"expression" => expr} ->
          case expr do
            "2+2" -> {:ok, "4"}
            "10*5" -> {:ok, "50"}
            _ -> {:error, "Unknown expression"}
          end
        end
      )

      weather_tool = ReqLLM.Tool.new!(
        name: "weather",
        description: "Get weather",
        parameter_schema: [
          location: [type: :string, required: true]
        ],
        callback: fn %{"location" => location} ->
          {:ok, "Sunny in #{location}"}
        end
      )

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.tools([calculator_tool, weather_tool])

      assert length(chain.tools) == 2
      tool_names = Enum.map(chain.tools, & &1.name)
      assert "calculator" in tool_names
      assert "weather" in tool_names
    end

    test "preserves tool order" do
      tools = [
        create_tool("tool_a", "Tool A"),
        create_tool("tool_b", "Tool B"),
        create_tool("tool_c", "Tool C")
      ]

      chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.tools(tools)

      tool_names = Enum.map(chain.tools, & &1.name)
      assert tool_names == ["tool_a", "tool_b", "tool_c"]
    end

    test "tool execution with custom context passing" do
      context_aware_tool = ReqLLM.Tool.new!(
        name: "context_tool",
        description: "Uses custom context",
        parameter_schema: [
          action: [type: :string, required: true]
        ],
        callback: fn params ->
          # In real usage, custom context would be passed via execution environment
          action = params["action"]
          {:ok, "Executed #{action}"}
        end
      )

      custom_context = %{user_id: 42, permissions: ["read", "write"]}

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.tools([context_aware_tool])
        |> ReqLLMChain.context(custom_context)

      assert chain.custom_context == custom_context
      assert length(chain.tools) == 1
    end
  end

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

  describe "custom context handling" do
    test "context merging behavior" do
      initial_context = %{user_id: 123, session: "abc"}
      additional_context = %{permissions: ["read"], session: "xyz"}

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.context(initial_context)
        |> ReqLLMChain.context(additional_context)

      # Should merge contexts, with later values overriding earlier ones
      expected_context = %{
        user_id: 123,
        session: "xyz",  # overridden
        permissions: ["read"]  # added
      }

      assert chain.custom_context == expected_context
    end

    test "context preserves complex data structures" do
      complex_context = %{
        user: %{
          id: 123,
          name: "Alice",
          preferences: %{
            theme: "dark",
            language: "en"
          }
        },
        session: %{
          id: "session_123",
          started_at: ~U[2024-01-01 00:00:00Z],
          tools_used: ["calculator", "weather"]
        },
        api_keys: %{
          weather: "weather_key_123",
          maps: "maps_key_456"
        }
      }

      chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.context(complex_context)

      assert chain.custom_context == complex_context
      assert chain.custom_context.user.preferences.theme == "dark"
      assert length(chain.custom_context.session.tools_used) == 2
    end

    test "nil context handling" do
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.context(nil)

      assert chain.custom_context == %{}
    end
  end

  describe "integration workflow patterns" do
    test "typical conversation workflow" do
      # Simulate a typical chatbot conversation workflow
      weather_tool = create_tool("get_weather", "Get current weather")
      
      conversation_chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.system("You are a helpful weather assistant")
        |> ReqLLMChain.tools([weather_tool])
        |> ReqLLMChain.context(%{user_id: "user_123", location: "San Francisco"})
        |> ReqLLMChain.user("What's the weather like?")

      # Verify the chain is properly set up for execution
      assert length(ReqLLMChain.messages(conversation_chain)) == 2
      assert length(conversation_chain.tools) == 1
      assert conversation_chain.custom_context.user_id == "user_123"

      # Simulate adding an assistant response
      response_chain =
        conversation_chain
        |> ReqLLMChain.assistant("I'll check the weather for you.")

      assert length(ReqLLMChain.messages(response_chain)) == 3
    end

    test "multi-tool workflow simulation" do
      # Create tools for a complex workflow
      calculator = create_tool("calculator", "Perform calculations")
      weather = create_tool("weather", "Get weather information")
      calendar = create_tool("calendar", "Manage calendar events")

      workflow_chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are a personal assistant")
        |> ReqLLMChain.tools([calculator, weather, calendar])
        |> ReqLLMChain.context(%{
          user_id: 42,
          timezone: "America/Los_Angeles",
          preferences: %{units: "imperial"}
        })
        |> ReqLLMChain.user("Calculate 15% tip on $80, check weather, and add lunch meeting")

      assert length(workflow_chain.tools) == 3
      assert workflow_chain.custom_context.timezone == "America/Los_Angeles"
      
      tool_names = Enum.map(workflow_chain.tools, & &1.name)
      assert "calculator" in tool_names
      assert "weather" in tool_names
      assert "calendar" in tool_names
    end

    test "conversation state accumulation" do
      # Test building up conversation state over multiple interactions
      base_chain = ReqLLMChain.new("anthropic:claude-3-sonnet")

      turn_1 = 
        base_chain
        |> ReqLLMChain.system("You are a helpful assistant")
        |> ReqLLMChain.user("Hello!")

      turn_2 =
        turn_1
        |> ReqLLMChain.assistant("Hello! How can I help you today?")
        |> ReqLLMChain.user("What's 2+2?")

      turn_3 =
        turn_2
        |> ReqLLMChain.assistant("2+2 equals 4.")
        |> ReqLLMChain.user("And what about 5*6?")

      # Each turn should accumulate messages
      assert length(ReqLLMChain.messages(turn_1)) == 2
      assert length(ReqLLMChain.messages(turn_2)) == 4
      assert length(ReqLLMChain.messages(turn_3)) == 6

      # Final conversation should contain all exchanges
      final_text = ReqLLMChain.text_content(turn_3)
      assert final_text =~ "Hello!"
      assert final_text =~ "2+2"
      assert final_text =~ "5*6"
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
      callback: fn params ->
        {:ok, "Test result for: #{params["input"]}"}
      end
    )
  end

  defp create_tool(name, description) do
    ReqLLM.Tool.new!(
      name: name,
      description: description,
      parameter_schema: [
        input: [type: :string, required: true]
      ],
      callback: fn params ->
        {:ok, "#{name} executed with: #{params["input"]}"}
      end
    )
  end
end

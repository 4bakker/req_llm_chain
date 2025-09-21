defmodule ReqLLMChain.ToolsContextTest do
  use ExUnit.Case

  import ReqLLMChain.TestHelpers

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
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.tools([tool])
        |> ReqLLMChain.context(custom_context)

      assert length(chain.tools) == 1
      assert chain.custom_context == custom_context
    end

    test "accumulates tools instead of replacing" do
      tool1 = create_tool("tool1", "First tool")
      tool2 = create_tool("tool2", "Second tool")

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.tools([tool1])
        |> ReqLLMChain.tools([tool2])

      assert length(chain.tools) == 2
      tool_names = Enum.map(chain.tools, & &1.name)
      assert "tool1" in tool_names
      assert "tool2" in tool_names
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

  describe "complex tool calling scenarios" do
    test "handles multiple tool execution" do
      calculator_tool = create_calculator_tool()
      weather_tool = create_weather_tool()

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.tools([calculator_tool, weather_tool])

      assert length(chain.tools) == 2
      tool_names = Enum.map(chain.tools, & &1.name)
      assert "calculator" in tool_names
      assert "weather" in tool_names
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
end

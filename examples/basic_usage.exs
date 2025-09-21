#!/usr/bin/env elixir

# Basic usage examples for ReqLLMChain
# Run with: elixir examples/basic_usage.exs

Mix.install([{:req_llm_chain, github: "4bakker/req_llm_chain"}])

defmodule BasicExamples do
  def run_all do
    IO.puts("🔗 ReqLLMChain Examples")
    IO.puts("=" |> String.duplicate(50))

    # Note: These examples use mock responses since they require API keys
    # In real usage, set your API keys via environment variables

    simple_conversation()
    multi_turn_conversation()
    tool_calling_example()
  end

  def simple_conversation do
    IO.puts("\n📝 Simple Conversation")
    IO.puts("-" |> String.duplicate(30))

    # Create a simple conversation
    chain =
      ReqLLMChain.new("anthropic:claude-3-sonnet")
      |> ReqLLMChain.system("You are a helpful math tutor")
      |> ReqLLMChain.user("What is 2 + 2?")

    IO.puts("Messages in chain: #{length(ReqLLMChain.messages(chain))}")
    IO.puts("Text content:")
    IO.puts(ReqLLMChain.text_content(chain))

    # In real usage, you'd call run() here:
    # {:ok, updated_chain, response} = ReqLLMChain.run(chain)
    # IO.puts("Assistant: #{response.text()}")
  end

  def multi_turn_conversation do
    IO.puts("\n🔄 Multi-turn Conversation")
    IO.puts("-" |> String.duplicate(30))

    # Build a multi-turn conversation
    chain =
      ReqLLMChain.new("openai:gpt-4", temperature: 0.7)
      |> ReqLLMChain.system("You are a travel advisor")
      |> ReqLLMChain.user("I want to visit Paris")
      |> ReqLLMChain.assistant("Paris is a wonderful choice! What time of year are you planning to visit?")
      |> ReqLLMChain.user("I'm thinking spring time")

    IO.puts("Conversation so far:")
    IO.puts(ReqLLMChain.text_content(chain))

    # Continue the conversation:
    # {:ok, updated_chain, response} = ReqLLMChain.run(chain)
  end

  def tool_calling_example do
    IO.puts("\n🔧 Tool Calling Example")
    IO.puts("-" |> String.duplicate(30))

    # Define some example tools
    weather_tool = create_weather_tool()
    calculator_tool = create_calculator_tool()

    # Create a chain with tools and custom context
    chain =
      ReqLLMChain.new("openai:gpt-4")
      |> ReqLLMChain.system("You are a helpful assistant with access to weather and calculator tools")
      |> ReqLLMChain.user("What's 15 * 8 and also what's the weather like in San Francisco?")
      |> ReqLLMChain.tools([weather_tool, calculator_tool])
      |> ReqLLMChain.context(%{
        user_id: 123,
        api_keys: %{weather: "demo_key"},
        preferences: %{units: "fahrenheit"}
      })

    IO.puts("Chain configured with #{length(chain.tools)} tools")
    IO.puts("Tools available: #{Enum.map(chain.tools, & &1.name) |> Enum.join(", ")}")
    IO.puts("Custom context keys: #{Map.keys(chain.custom_context) |> Enum.join(", ")}")

    # In real usage with API keys:
    # {:ok, final_chain, response} = ReqLLMChain.run(chain)
    # IO.puts("Final response: #{response.text()}")
  end

  defp create_weather_tool do
    ReqLLM.Tool.new!(
      name: "get_weather",
      description: "Get current weather for a location",
      parameter_schema: [
        location: [type: :string, required: true, doc: "City name, e.g., 'San Francisco'"],
        units: [type: :string, default: "fahrenheit", doc: "Temperature units"]
      ],
      callback: fn params ->
        # Mock weather service call
        location = params["location"]
        units = params["units"] || "fahrenheit"

        IO.puts("  🌤️  Fetching weather for #{location} (units: #{units})")

        # Mock weather data
        weather = %{
          location: location,
          temperature: if(units == "celsius", do: 22, else: 72),
          condition: "sunny",
          humidity: 65
        }

        {:ok, weather}
      end
    )
  end

  defp create_calculator_tool do
    ReqLLM.Tool.new!(
      name: "calculate",
      description: "Perform mathematical calculations",
      parameter_schema: [
        expression: [type: :string, required: true, doc: "Mathematical expression like '15 * 8'"]
      ],
      callback: fn params ->
        expression = params["expression"]
        IO.puts("  🧮 Calculating: #{expression}")

        # Simple evaluation (in production, use a proper math parser)
        try do
          # This is just for demo - use a proper math evaluator in production
          result =
            case expression do
              "15 * 8" -> 120
              "2 + 2" -> 4
              _ -> "Unable to calculate #{expression}"
            end

          {:ok, "#{expression} = #{result}"}
        rescue
          _ -> {:error, "Invalid expression: #{expression}"}
        end
      end
    )
  end
end

# Run the examples
BasicExamples.run_all()

IO.puts("\n✅ Examples completed!")
IO.puts("\n💡 To run with real API calls:")
IO.puts("   1. Set environment variables for your API keys:")
IO.puts("      export ANTHROPIC_API_KEY=your_key")
IO.puts("      export OPENAI_API_KEY=your_key")
IO.puts("   2. Uncomment the ReqLLMChain.run() calls in the examples")
IO.puts("   3. Run: elixir examples/basic_usage.exs")

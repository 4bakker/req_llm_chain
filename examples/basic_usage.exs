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
      ReqLLMChain.new("openai:gpt-4")
      |> ReqLLMChain.system("You are a helpful math tutor")
      |> ReqLLMChain.user("What is 2 + 2?")

    IO.puts("Messages in chain: #{length(ReqLLMChain.messages(chain))}")
    IO.puts("Text content:")
    IO.puts(ReqLLMChain.text_content(chain))

    # Try to get a real LLM response
    IO.puts("\n🤖 LLM Response:")
    try do
      case ReqLLMChain.run(chain) do
        {:ok, _updated_chain, response} ->
          IO.puts("✅ #{response.text()}")
          IO.puts("📊 Usage: #{inspect(response.usage())}")

        {:error, %{__struct__: error_type} = error} when error_type in [ReqLLM.Error.API.Request, ReqLLM.Error.API.Authentication, ReqLLM.Error.Invalid.Parameter] ->
          IO.puts("⚠️  API error. To see real responses:")
          IO.puts("   export OPENAI_API_KEY=your_key")
          if Map.has_key?(error, :reason) and error.reason do
            IO.puts("   Reason: #{error.reason}")
          end

        {:error, error} ->
          IO.puts("❌ Error: #{inspect(error)}")
          IO.puts("💡 Make sure you have valid API keys set")
      end
    rescue
      error ->
        IO.puts("⚠️  API error. To see real responses:")
        IO.puts("   export OPENAI_API_KEY=your_key")
        IO.puts("   Error: #{inspect(error)}")
    end
  end

  def multi_turn_conversation do
    IO.puts("\n🔄 Multi-turn Conversation")
    IO.puts("-" |> String.duplicate(30))

    # Start with initial conversation
    initial_chain =
      ReqLLMChain.new("openai:gpt-4", temperature: 0.7)
      |> ReqLLMChain.system("You are a travel advisor")
      |> ReqLLMChain.user("I want to visit Paris")

    IO.puts("Initial conversation:")
    IO.puts(ReqLLMChain.text_content(initial_chain))

    # Get first LLM response
    IO.puts("\n🤖 Travel Advisor Response:")
    try do
      case ReqLLMChain.run(initial_chain) do
      {:ok, chain_with_response, response} ->
        IO.puts("✅ #{response.text()}")

        # Continue the conversation with user's follow-up
        final_chain =
          chain_with_response
          |> ReqLLMChain.user("I'm thinking spring time")

        IO.puts("\n📝 Full conversation so far:")
        IO.puts(ReqLLMChain.text_content(final_chain))

        # Get final response
        IO.puts("\n🤖 Final Response:")
        case ReqLLMChain.run(final_chain) do
          {:ok, _final_chain, final_response} ->
            IO.puts("✅ #{final_response.text()}")
          {:error, error} ->
            IO.puts("❌ Error in follow-up: #{inspect(error)}")
        end

      {:error, %{__struct__: error_type} = error} when error_type in [ReqLLM.Error.API.Request, ReqLLM.Error.API.Authentication, ReqLLM.Error.Invalid.Parameter] ->
        IO.puts("⚠️  API error. To see real responses:")
        IO.puts("   export OPENAI_API_KEY=your_key")
        if Map.has_key?(error, :reason) and error.reason do
          IO.puts("   Reason: #{error.reason}")
        end
        # Show what the conversation would look like
        demo_chain =
          initial_chain
          |> ReqLLMChain.assistant("Paris is wonderful! When are you planning to visit?")
          |> ReqLLMChain.user("I'm thinking spring time")
        IO.puts("\n📝 Demo conversation flow:")
        IO.puts(ReqLLMChain.text_content(demo_chain))

      {:error, error} ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
    rescue
      error ->
        IO.puts("⚠️  API error. To see real responses:")
        IO.puts("   export OPENAI_API_KEY=your_key")
        IO.puts("   Error: #{inspect(error)}")
    end
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

    # Try tool calling workflow
    IO.puts("\n🤖 Tool Calling Workflow:")
    try do
      case ReqLLMChain.run(chain) do
      {:ok, final_chain, response} ->
        IO.puts("✅ Final response: #{response.text()}")
        IO.puts("📊 Usage: #{inspect(response.usage())}")
        IO.puts("🔧 Tools used in conversation:")

        # Show the full conversation with tool calls
        messages = ReqLLMChain.messages(final_chain)
        Enum.each(messages, fn msg ->
          case msg.role do
            :system -> IO.puts("  💬 System: #{String.slice(msg.content, 0, 50)}...")
            :user -> IO.puts("  👤 User: #{msg.content}")
            :assistant -> IO.puts("  🤖 Assistant: #{String.slice(msg.content, 0, 100)}...")
            :tool -> IO.puts("  🔧 Tool result: [tool executed]")
          end
        end)

      {:error, %{__struct__: error_type} = error} when error_type in [ReqLLM.Error.API.Request, ReqLLM.Error.API.Authentication, ReqLLM.Error.Invalid.Parameter] ->
        IO.puts("⚠️  API error. To see real tool calling:")
        IO.puts("   export OPENAI_API_KEY=your_key")
        if Map.has_key?(error, :reason) and error.reason do
          IO.puts("   Reason: #{error.reason}")
        end
        IO.puts("   # Tool workflow would:")
        IO.puts("   # 1. Send user question to LLM")
        IO.puts("   # 2. LLM decides to use weather/calculator tools")
        IO.puts("   # 3. Tools execute and return results")
        IO.puts("   # 4. LLM provides final answer using tool results")

      {:error, error} ->
        IO.puts("❌ Error: #{inspect(error)}")
        IO.puts("💡 Make sure you have valid API keys set")
    end
    rescue
      error ->
        IO.puts("⚠️  API error. To see real tool calling:")
        IO.puts("   export ANTHROPIC_API_KEY=your_key")
        IO.puts("   Error: #{inspect(error)}")
    end
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
IO.puts("\n💡 To see REAL LLM responses:")
IO.puts("   1. Set your API keys:")
IO.puts("      export ANTHROPIC_API_KEY=your_anthropic_key")
IO.puts("      export OPENAI_API_KEY=your_openai_key")
IO.puts("   2. Run again: elixir examples/basic_usage.exs")
IO.puts("   3. Watch the magic happen! 🪄")
IO.puts("")
IO.puts("🔧 What you'll see with API keys:")
IO.puts("   • Real math answers (2+2=4)")
IO.puts("   • Actual travel advice")
IO.puts("   • Tool calling in action")
IO.puts("   • Token usage statistics")
IO.puts("   • Full conversation flows")

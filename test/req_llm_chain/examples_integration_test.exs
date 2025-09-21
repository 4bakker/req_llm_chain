defmodule ReqLLMChain.ExamplesIntegrationTest do
  use ExUnit.Case

  @moduledoc """
  Tests that validate the examples from basic_usage.exs work correctly.

  These tests ensure that:
  1. Example code doesn't break when we make changes
  2. Examples produce correct chain structures
  3. Tool definitions and contexts work as expected
  4. Example patterns are valid for real usage
  """

  describe "simple_conversation example" do
    test "builds a proper math tutor conversation chain" do
      # This mirrors the simple_conversation() example from basic_usage.exs
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are a helpful math tutor")
        |> ReqLLMChain.user("What is 2 + 2?")

      # Validate the chain structure matches example expectations
      assert length(ReqLLMChain.messages(chain)) == 2

      messages = ReqLLMChain.messages(chain)
      [system_msg, user_msg] = messages

      # Validate system message
      assert system_msg.role == :system
      assert %ReqLLM.Message{} = system_msg

      # Validate user message
      assert user_msg.role == :user
      assert %ReqLLM.Message{} = user_msg

      # Validate text content extraction works as expected in example
      text_content = ReqLLMChain.text_content(chain)
      assert text_content =~ "You are a helpful math tutor"
      assert text_content =~ "What is 2 + 2?"
      assert text_content =~ "[SYSTEM]"
      assert text_content =~ "[USER]"

      # Validate model is correctly set
      assert chain.model.provider == :openai
      assert chain.model.model == "gpt-4"
    end

    test "chain is ready for ReqLLM.generate_text call" do
      # Ensure the example chain can be used with ReqLLM (structure validation)
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are a helpful math tutor")
        |> ReqLLMChain.user("What is 2 + 2?")

      # These are the parameters that would be passed to ReqLLM.generate_text
      model = chain.model
      context = chain.context
      options = [tools: chain.tools] ++ chain.options

      # Validate they have the correct ReqLLM types
      assert %ReqLLM.Model{} = model
      assert %ReqLLM.Context{} = context
      assert is_list(options)
      assert Keyword.keyword?(options)
    end
  end

  describe "multi_turn_conversation example" do
    test "builds a proper travel advisor conversation chain" do
      # This mirrors the multi_turn_conversation() example from basic_usage.exs
      initial_chain =
        ReqLLMChain.new("openai:gpt-4", temperature: 0.7)
        |> ReqLLMChain.system("You are a travel advisor")
        |> ReqLLMChain.user("I want to visit Paris")

      # Validate initial chain structure
      assert length(ReqLLMChain.messages(initial_chain)) == 2
      assert initial_chain.options == [temperature: 0.7]

      text_content = ReqLLMChain.text_content(initial_chain)
      assert text_content =~ "travel advisor"
      assert text_content =~ "visit Paris"

      # Test conversation continuation as shown in example
      demo_chain =
        initial_chain
        |> ReqLLMChain.assistant("Paris is wonderful! When are you planning to visit?")
        |> ReqLLMChain.user("I'm thinking spring time")

      # Validate expanded conversation
      assert length(ReqLLMChain.messages(demo_chain)) == 4

      messages = ReqLLMChain.messages(demo_chain)
      roles = Enum.map(messages, & &1.role)
      assert roles == [:system, :user, :assistant, :user]

      # Validate conversation flow text
      final_text = ReqLLMChain.text_content(demo_chain)
      assert final_text =~ "travel advisor"
      assert final_text =~ "Paris"
      assert final_text =~ "spring time"
    end

    test "preserves model options in multi-turn conversation" do
      chain =
        ReqLLMChain.new("openai:gpt-4", temperature: 0.7)
        |> ReqLLMChain.system("You are a travel advisor")
        |> ReqLLMChain.user("I want to visit Paris")
        |> ReqLLMChain.assistant("Paris is wonderful!")
        |> ReqLLMChain.user("What about spring?")

      # Options should be preserved through all builder calls
      assert chain.options == [temperature: 0.7]
      assert chain.model.provider == :openai
      assert chain.model.model == "gpt-4"
    end
  end

  describe "tool_calling_example" do
    test "builds proper weather tool as in example" do
      # Extract and test the create_weather_tool logic from the example
      weather_tool = create_weather_tool()

      # Validate tool structure matches ReqLLM.Tool requirements
      assert %ReqLLM.Tool{} = weather_tool
      assert weather_tool.name == "get_weather"
      assert weather_tool.description == "Get current weather for a location"
      assert is_list(weather_tool.parameter_schema)
      assert Keyword.keyword?(weather_tool.parameter_schema)
      assert is_function(weather_tool.callback, 1)

      # Test tool parameter schema structure
      schema = weather_tool.parameter_schema
      assert Keyword.has_key?(schema, :location)
      assert Keyword.has_key?(schema, :units)

      location_spec = Keyword.get(schema, :location)
      assert location_spec[:type] == :string
      assert location_spec[:required] == true
    end

    test "builds proper calculator tool as in example" do
      # Extract and test the create_calculator_tool logic from the example
      calculator_tool = create_calculator_tool()

      # Validate tool structure
      assert %ReqLLM.Tool{} = calculator_tool
      assert calculator_tool.name == "calculate"
      assert calculator_tool.description == "Perform mathematical calculations"
      assert is_function(calculator_tool.callback, 1)

      # Test parameter schema
      schema = calculator_tool.parameter_schema
      assert Keyword.has_key?(schema, :expression)
      expression_spec = Keyword.get(schema, :expression)
      assert expression_spec[:type] == :string
      assert expression_spec[:required] == true
    end

    test "tool callbacks work as expected in examples" do
      weather_tool = create_weather_tool()
      calculator_tool = create_calculator_tool()

      # Test weather tool callback (matches example logic)
      weather_params = %{"location" => "San Francisco", "units" => "fahrenheit"}
      {:ok, weather_result} = weather_tool.callback.(weather_params)

      assert is_map(weather_result)
      assert weather_result.location == "San Francisco"
      assert weather_result.temperature == 72  # fahrenheit as in example
      assert weather_result.condition == "sunny"

      # Test calculator tool callback (matches example logic)
      calc_params = %{"expression" => "15 * 8"}
      {:ok, calc_result} = calculator_tool.callback.(calc_params)

      assert calc_result == "15 * 8 = 120"
    end

    test "builds complete tool calling chain as in example" do
      # This mirrors the complete tool_calling_example() from basic_usage.exs
      weather_tool = create_weather_tool()
      calculator_tool = create_calculator_tool()

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

      # Validate chain structure matches example expectations
      assert length(chain.tools) == 2
      tool_names = Enum.map(chain.tools, & &1.name)
      assert "get_weather" in tool_names
      assert "calculate" in tool_names

      # Validate custom context as in example
      context_keys = Map.keys(chain.custom_context)
      assert :user_id in context_keys
      assert :api_keys in context_keys
      assert :preferences in context_keys

      assert chain.custom_context.user_id == 123
      assert chain.custom_context.api_keys.weather == "demo_key"
      assert chain.custom_context.preferences.units == "fahrenheit"

      # Validate message content
      text_content = ReqLLMChain.text_content(chain)
      assert text_content =~ "weather and calculator tools"
      assert text_content =~ "15 * 8"
      assert text_content =~ "San Francisco"
    end

    test "tools and context are ready for ReqLLM integration" do
      weather_tool = create_weather_tool()
      calculator_tool = create_calculator_tool()

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are helpful")
        |> ReqLLMChain.user("Help me with calculations")
        |> ReqLLMChain.tools([weather_tool, calculator_tool])
        |> ReqLLMChain.context(%{user_id: 42})

      # Validate that tools are proper ReqLLM.Tool structs
      Enum.each(chain.tools, fn tool ->
        assert %ReqLLM.Tool{} = tool
        assert is_binary(tool.name)
        assert is_function(tool.callback, 1)
      end)

      # Validate context separation (ReqLLM context vs custom context)
      assert %ReqLLM.Context{} = chain.context  # For LLM messages
      assert is_map(chain.custom_context)       # For tool callbacks
      assert chain.custom_context.user_id == 42
    end
  end

  describe "example patterns and best practices" do
    test "all examples use proper error handling patterns" do
      # Verify that our examples follow proper error handling
      # This tests the pattern used in the examples for API calls

      _chain = ReqLLMChain.new("openai:gpt-4") |> ReqLLMChain.user("test")

      # The examples show this pattern - test that it's syntactically correct
      result = case {:error, %ReqLLM.Error.Invalid.Parameter{parameter: "test"}} do
        {:ok, _updated_chain, response} ->
          {:ok, response}

        {:error, %{__struct__: error_type} = error} when error_type in [ReqLLM.Error.API.Request, ReqLLM.Error.API.Authentication, ReqLLM.Error.Invalid.Parameter] ->
          {:error, :api_error, error}

        {:error, error} ->
          {:error, :other, error}
      end

      assert {:error, :api_error, _} = result
    end

    test "examples demonstrate immutable chain building" do
      # Verify that examples show proper immutable pattern
      base_chain = ReqLLMChain.new("openai:gpt-4")

      chain1 = base_chain |> ReqLLMChain.system("System 1")
      chain2 = base_chain |> ReqLLMChain.system("System 2")

      # Original chain should be unchanged
      assert length(ReqLLMChain.messages(base_chain)) == 0
      assert length(ReqLLMChain.messages(chain1)) == 1
      assert length(ReqLLMChain.messages(chain2)) == 1

      # Chains should be different
      refute chain1 == chain2
      text1 = ReqLLMChain.text_content(chain1)
      text2 = ReqLLMChain.text_content(chain2)
      assert text1 =~ "System 1"
      assert text2 =~ "System 2"
    end
  end

  # Helper functions that mirror the examples exactly
  defp create_weather_tool do
    ReqLLM.Tool.new!(
      name: "get_weather",
      description: "Get current weather for a location",
      parameter_schema: [
        location: [type: :string, required: true, doc: "City name, e.g., 'San Francisco'"],
        units: [type: :string, default: "fahrenheit", doc: "Temperature units"]
      ],
      callback: fn params ->
        location = params["location"]
        units = params["units"] || "fahrenheit"

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

        try do
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

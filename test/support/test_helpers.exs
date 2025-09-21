defmodule ReqLLMChain.TestHelpers do
  @moduledoc """
  Shared test helpers for ReqLLMChain test suite.
  """

  @doc """
  Creates a basic test tool for testing purposes.
  """
  def create_test_tool do
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

  @doc """
  Creates a tool with custom name and description.
  """
  def create_tool(name, description) do
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

  @doc """
  Creates a calculator tool for testing complex scenarios.
  """
  def create_calculator_tool do
    ReqLLM.Tool.new!(
      name: "calculator",
      description: "Basic calculator",
      parameter_schema: [
        expression: [type: :string, required: true]
      ],
      callback: fn %{"expression" => expr} ->
        case expr do
          "2+2" -> {:ok, "4"}
          "10*5" -> {:ok, "50"}
          "15*8" -> {:ok, "120"}
          _ -> {:error, "Unknown expression"}
        end
      end
    )
  end

  @doc """
  Creates a weather tool for testing.
  """
  def create_weather_tool do
    ReqLLM.Tool.new!(
      name: "weather",
      description: "Get weather",
      parameter_schema: [
        location: [type: :string, required: true]
      ],
      callback: fn %{"location" => location} ->
        {:ok, "Sunny in #{location}"}
      end
    )
  end

  @doc """
  Creates a failing tool for error testing.
  """
  def create_failing_tool do
    ReqLLM.Tool.new!(
      name: "failing_tool",
      description: "A tool that fails",
      parameter_schema: [
        input: [type: :string, required: true]
      ],
      callback: fn _params ->
        {:error, "Tool execution failed"}
      end
    )
  end
end

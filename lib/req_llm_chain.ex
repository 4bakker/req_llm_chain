defmodule ReqLLMChain do
  @moduledoc """
  A lightweight conversation builder for ReqLLM.

  Provides LangChain-style builder patterns, tool calling loops, and conversation
  state management on top of ReqLLM's provider-agnostic architecture.

  ## Features

  - **Builder Pattern**: Fluent API for building conversations
  - **Tool Calling Loops**: Automatic tool execution until completion
  - **Conversation State**: Message history management
  - **Custom Context**: App-specific data passed to tools
  - **45+ Providers**: All ReqLLM providers supported

  ## Quick Start

      # Simple conversation
      {:ok, chain, response} =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.system("You are a helpful assistant")
        |> ReqLLMChain.user("What's 2+2?")
        |> ReqLLMChain.run()

      # Tool calling with custom context
      {:ok, chain, response} =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are a weather assistant")
        |> ReqLLMChain.user("What's the weather in NYC?")
        |> ReqLLMChain.tools([weather_tool])
        |> ReqLLMChain.context(%{api_key: "weather_key", user_id: 123})
        |> ReqLLMChain.run()

      # Continue conversation
      {:ok, chain2, response2} =
        chain
        |> ReqLLMChain.user("What about tomorrow?")
        |> ReqLLMChain.run()

  ## Comparison to LangChain

  | Feature | ReqLLMChain | LangChain |
  |---------|-------------|-----------|
  | **Providers** | 45+ | 10 |
  | **Code complexity** | ~500 lines | 20,000+ lines |
  | **Data structure** | Simple struct | Complex Ecto schema |
  | **Tool calling** | Built-in loops | Manual management |
  | **Builder pattern** | ✅ | ✅ |
  | **Conversation state** | ✅ | ✅ |

  """

  alias ReqLLMChain.Chain

  @doc """
  Creates a new conversation chain.

  ## Parameters

  - `model_spec` - Model specification (string, tuple, or ReqLLM.Model struct)
  - `opts` - Optional keyword list of options

  ## Options

  - `:temperature` - Controls randomness (0.0-2.0)
  - `:max_tokens` - Maximum tokens in response
  - `:stream` - Enable streaming responses

  ## Examples

      # String format (most common)
      chain = ReqLLMChain.new("anthropic:claude-3-sonnet")

      # With options
      chain = ReqLLMChain.new("openai:gpt-4", temperature: 0.7, max_tokens: 1000)

      # Tuple format
      chain = ReqLLMChain.new({:anthropic, "claude-3-sonnet", temperature: 0.5})

  """
  @spec new(ReqLLM.model_spec(), keyword()) :: Chain.t()
  defdelegate new(model_spec, opts \\ []), to: Chain

  @doc """
  Adds a system message to the conversation.

  System messages set the context and behavior for the AI assistant.

  ## Examples

      chain
      |> ReqLLMChain.system("You are a helpful coding assistant")
      |> ReqLLMChain.system("Always provide examples with your explanations")

  """
  @spec system(Chain.t(), String.t()) :: Chain.t()
  defdelegate system(chain, content), to: Chain

  @doc """
  Adds a user message to the conversation.

  ## Examples

      chain
      |> ReqLLMChain.user("What's the capital of France?")
      |> ReqLLMChain.user("Tell me more about its history")

  """
  @spec user(Chain.t(), String.t()) :: Chain.t()
  defdelegate user(chain, content), to: Chain

  @doc """
  Adds an assistant message to the conversation.

  Useful for providing examples or continuing conversations from stored state.

  ## Examples

      chain
      |> ReqLLMChain.user("What's 2+2?")
      |> ReqLLMChain.assistant("2+2 equals 4")
      |> ReqLLMChain.user("What about 3+3?")

  """
  @spec assistant(Chain.t(), String.t()) :: Chain.t()
  defdelegate assistant(chain, content), to: Chain

  @doc """
  Adds tools that the AI can call.

  ## Examples

      weather_tool = ReqLLM.Tool.new!(
        name: "get_weather",
        description: "Get current weather",
        parameter_schema: [
          location: [type: :string, required: true]
        ],
        callback: {WeatherService, :get_current}
      )

      chain
      |> ReqLLMChain.tools([weather_tool])

  """
  @spec tools(Chain.t(), [ReqLLM.Tool.t()]) :: Chain.t()
  defdelegate tools(chain, tool_list), to: Chain

  @doc """
  Adds custom context data available to tools.

  This data is passed to tool callbacks when they're executed, allowing
  tools to access app-specific information like user IDs, API keys, etc.

  ## Examples

      chain
      |> ReqLLMChain.context(%{
        user_id: 123,
        api_keys: %{weather: "key123"},
        permissions: [:read, :write]
      })

  """
  @spec context(Chain.t(), map()) :: Chain.t()
  defdelegate context(chain, custom_context), to: Chain

  @doc """
  Runs the conversation once and returns the response.

  For tool calling scenarios, use `run/2` instead.

  ## Examples

      {:ok, updated_chain, response} =
        chain
        |> ReqLLMChain.user("Hello!")
        |> ReqLLMChain.run()

      IO.puts(response.text())

  """
  @spec run_once(Chain.t()) :: {:ok, Chain.t(), ReqLLM.Response.t()} | {:error, term()}
  def run_once(chain) do
    try do
      Chain.run_once(chain)
    rescue
      error ->
        {:error, error}
    end
  end

  @doc """
  Runs the conversation with automatic tool calling loops.

  Continues calling the LLM and executing tools until the conversation
  reaches a natural stopping point (no more tool calls needed).

  ## Parameters

  - `chain` - The conversation chain
  - `max_iterations` - Maximum number of LLM calls (default: 10)

  ## Examples

      {:ok, final_chain, final_response} =
        chain
        |> ReqLLMChain.user("What's the weather in NYC and what should I wear?")
        |> ReqLLMChain.tools([weather_tool, clothing_tool])
        |> ReqLLMChain.run()

  """
  @spec run(Chain.t(), pos_integer()) ::
          {:ok, Chain.t(), ReqLLM.Response.t()} | {:error, term()}
  def run(chain, max_iterations \\ 10) do
    try do
      Chain.run(chain, max_iterations)
    rescue
      error ->
        {:error, error}
    end
  end

  @doc """
  Streams the conversation response.

  ## Examples

      {:ok, updated_chain, stream} =
        chain
        |> ReqLLMChain.user("Tell me a story")
        |> ReqLLMChain.stream()

      stream
      |> Stream.each(&IO.write(&1.text))
      |> Stream.run()

  """
  @spec stream(Chain.t()) :: {:ok, Chain.t(), Enumerable.t()} | {:error, term()}
  defdelegate stream(chain), to: Chain

  @doc """
  Extracts just the text from the conversation history.

  Useful for debugging or displaying conversation state.

  ## Examples

      messages = ReqLLMChain.messages(chain)
      text_only = ReqLLMChain.text_content(chain)

  """
  @spec text_content(Chain.t()) :: String.t()
  defdelegate text_content(chain), to: Chain

  @doc """
  Gets the current conversation messages.

  ## Examples

      messages = ReqLLMChain.messages(chain)
      length(messages) # => 4

  """
  @spec messages(Chain.t()) :: [ReqLLM.Message.t()]
  defdelegate messages(chain), to: Chain
end

# ReqLLMChain

A conversation builder for [ReqLLM](https://hex.pm/packages/req_llm) with builder patterns, automatic tool calling loops, and conversation state management.

## Installation

Add `req_llm_chain` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:req_llm_chain, "~> 0.1"},
    {:req_llm, "~> 1.0-rc"}
  ]
end
```

## Quick Start

### Simple Conversation

```elixir
# Basic conversation
{:ok, chain, response} =
  ReqLLMChain.new("anthropic:claude-3-sonnet")
  |> ReqLLMChain.system("You are a helpful assistant")
  |> ReqLLMChain.user("What's the capital of France?")
  |> ReqLLMChain.run()

IO.puts response.text()
# => "The capital of France is Paris."
```

### Multi-turn Conversation

```elixir
# Continue the conversation
{:ok, chain2, response2} =
  chain
  |> ReqLLMChain.user("Tell me about its history")
  |> ReqLLMChain.run()

IO.puts response2.text()
# => "Paris has a rich history dating back over 2,000 years..."
```

### Tool Calling with Custom Context

```elixir
# Define a weather tool
weather_tool = ReqLLM.Tool.new!(
  name: "get_weather",
  description: "Get current weather for a location",
  parameter_schema: [
    location: [type: :string, required: true, doc: "City name"]
  ],
  callback: {WeatherService, :get_current_weather}
)

# Use the tool with custom context
{:ok, chain, response} =
  ReqLLMChain.new("openai:gpt-4")
  |> ReqLLMChain.system("You are a weather assistant")
  |> ReqLLMChain.user("What's the weather in NYC?")
  |> ReqLLMChain.tools([weather_tool])
  |> ReqLLMChain.context(%{
    api_key: System.get_env("WEATHER_API_KEY"),
    user_id: 123
  })
  |> ReqLLMChain.run()

IO.puts response.text()
# => "The current weather in New York City is sunny with a temperature of 72°F..."
```

## Usage

### Builder Pattern

Build conversations step by step:

```elixir
ReqLLMChain.new("anthropic:claude-3-sonnet")
|> ReqLLMChain.system("You are helpful")
|> ReqLLMChain.user("Hello")
|> ReqLLMChain.assistant("Hi there!")  # Can add assistant messages too
|> ReqLLMChain.user("How are you?")
|> ReqLLMChain.run()
```

### Tool Calling

`run/2` automatically handles tool calling workflows:

```elixir
{:ok, chain, response} =
  ReqLLMChain.new("openai:gpt-4")
  |> ReqLLMChain.user("What should I wear in Seattle today?")
  |> ReqLLMChain.tools([weather_tool, clothing_tool])
  |> ReqLLMChain.context(%{user_preferences: %{style: "casual"}})
  |> ReqLLMChain.run()
```

### Conversation State

Access conversation history:

```elixir
# Check conversation state
messages = ReqLLMChain.messages(chain)
length(messages) # => 6 

# Get text-only view
text_content = ReqLLMChain.text_content(chain)
IO.puts text_content
```

### Custom Context for Tools

Pass application-specific data to tools:

```elixir
defmodule WeatherService do
  def get_current_weather(params, context) do
    api_key = context.api_key
    user_id = context.user_id
    location = params["location"]
    
    # Use api_key to call weather service
    # Return weather data
    {:ok, %{temperature: 72, condition: "sunny"}}
  end
end
```

### Streaming

```elixir
{:ok, chain, stream} =
  ReqLLMChain.new("anthropic:claude-3-sonnet")
  |> ReqLLMChain.user("Tell me a long story")
  |> ReqLLMChain.stream()

# Stream text as it arrives
stream
|> Stream.filter(&(&1.type == :content))
|> Stream.map(&(&1.text))
|> Stream.each(&IO.write/1)
|> Stream.run()
```

## Supported Providers

Works with any ReqLLM provider:

```elixir
# Provider:model format
ReqLLMChain.new("anthropic:claude-3-5-sonnet")
ReqLLMChain.new("openai:gpt-4")
ReqLLMChain.new("xai:grok-4")
ReqLLMChain.new("google:gemini-2.0-flash")
ReqLLMChain.new("groq:llama-3.1-70b")
ReqLLMChain.new("deepseek:coder")
```

## Configuration

### Model Configuration

```elixir
# With options
chain = ReqLLMChain.new(
  "anthropic:claude-3-sonnet",
  temperature: 0.7,
  max_tokens: 2000
)

# Tuple format
chain = ReqLLMChain.new({
  :openai, 
  "gpt-4",
  temperature: 0.1,
  max_tokens: 500
})

# Model struct format
model = ReqLLM.Model.from!("xai:grok-4")
chain = ReqLLMChain.new(model)
```

### Error Handling

Following ReqLLM usage rules, pattern match on specific error types:

```elixir
case ReqLLMChain.run(chain, max_iterations: 5) do
  {:ok, final_chain, response} ->
    IO.puts "Success: #{response.text()}"
    
  {:error, :max_iterations_reached} ->
    IO.puts "Tool calling loop exceeded maximum iterations"
    
  {:error, %ReqLLM.Error.API.RateLimit{retry_after: seconds}} ->
    Logger.warn("Rate limited, retry after #{seconds}s")
    :timer.sleep(seconds * 1000)
    
  {:error, %ReqLLM.Error.API.Authentication{}} ->
    Logger.error("Authentication failed - check API key")
    
  {:error, %ReqLLM.Error.Invalid.Provider{provider: provider}} ->
    Logger.error("Unsupported provider: #{provider}")
    
  {:error, reason} ->
    IO.puts "Error: #{inspect(reason)}"
end
```

### Tool Definition Examples

Following ReqLLM usage rules for production-ready tools:

```elixir
# Production tool with module callback (recommended)
weather_tool = ReqLLM.Tool.new!(
  name: "get_weather",
  description: "Get current weather conditions for a specific location", 
  parameter_schema: [
    location: [type: :string, required: true, doc: "City name or coordinates"],
    units: [type: :string, default: "metric", doc: "Temperature units"]
  ],
  callback: {MyApp.WeatherAPI, :fetch_weather}
)

# Simple inline tool (development/testing)
simple_tool = ReqLLM.Tool.new!(
  name: "calculator",
  description: "Perform basic calculations",
  parameter_schema: [
    expression: [type: :string, required: true, doc: "Math expression to evaluate"]
  ],
  callback: fn params ->
    case params["expression"] do
      "2+2" -> {:ok, "4"}
      _ -> {:error, "Unsupported calculation"}
    end
  end
)

# Module implementation with proper error handling
defmodule MyApp.WeatherAPI do
  require Logger
  
  def fetch_weather(%{location: location, units: units}) do
    case HTTPClient.get("/weather", location: location, units: units) do
      {:ok, %{status: 200, body: data}} ->
        {:ok, data}
        
      {:ok, %{status: 404}} ->
        {:error, "Location not found"}
        
      {:error, reason} ->
        Logger.error("Weather service error: #{inspect(reason)}")
        {:error, "Weather service unavailable"}
    end
  rescue
    error ->
      Logger.error("Weather fetch failed: #{Exception.message(error)}")
      {:error, "Unable to fetch weather data"}
  end
end
# Additional examples available in examples/production_ready_example.exs
```


## License

MIT

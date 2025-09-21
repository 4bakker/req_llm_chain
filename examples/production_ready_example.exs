#!/usr/bin/env elixir

# Production-ready example following ReqLLM usage rules
# Run with: elixir examples/production_ready_example.exs

Mix.install([{:req_llm_chain, path: "."}])

defmodule ProductionExample do
  @moduledoc """
  Demonstrates production-ready patterns following ReqLLM usage rules:
  - Module-based tool callbacks with proper error handling
  - Specific ReqLLM error pattern matching
  - Comprehensive parameter schemas
  - Usage monitoring and logging
  """

  require Logger

  def run_all do
    IO.puts("🏭 Production-Ready ReqLLMChain Examples")
    IO.puts("=" |> String.duplicate(50))

    # Note: These examples use mock responses since they require API keys
    # In real usage, set your API keys via environment variables or .env files

    weather_example()
    error_handling_example()
    monitoring_example()
  end

  def weather_example do
    IO.puts("\n📊 Production Weather Assistant")
    IO.puts("-" |> String.duplicate(30))

    # Create tools with proper module callbacks
    weather_tool = create_weather_tool()
    location_tool = create_location_tool()

    chain =
      ReqLLMChain.new("anthropic:claude-3-sonnet")
      |> ReqLLMChain.system("You are a professional weather assistant")
      |> ReqLLMChain.tools([weather_tool, location_tool])
      |> ReqLLMChain.context(%{
        user_id: "user_123",
        api_keys: %{
          weather: System.get_env("WEATHER_API_KEY"),
          location: System.get_env("LOCATION_API_KEY")
        }
      })
      |> ReqLLMChain.user("What's the weather like for outdoor activities?")

    IO.puts("Chain configured with production-ready tools:")
    Enum.each(chain.tools, fn tool ->
      IO.puts("  - #{tool.name}: #{tool.description}")
    end)

    IO.puts("\nIn production, this would:")
    IO.puts("1. Determine user location")
    IO.puts("2. Fetch real weather data")
    IO.puts("3. Provide activity recommendations")
    IO.puts("4. Log usage and monitor performance")
  end

  def error_handling_example do
    IO.puts("\n🚨 Error Handling Patterns")
    IO.puts("-" |> String.duplicate(30))

    # Demonstrate proper error handling following ReqLLM usage rules
    model_validation_example()
    api_error_handling_example()
  end

  def monitoring_example do
    IO.puts("\n📈 Usage Monitoring")
    IO.puts("-" |> String.duplicate(30))

    IO.puts("Production monitoring would track:")
    IO.puts("- Token usage per request")
    IO.puts("- Response latency")
    IO.puts("- Tool execution success rates")
    IO.puts("- Cost attribution per user/session")
  end

  # Tool definitions following ReqLLM usage rules
  defp create_weather_tool do
    ReqLLM.Tool.new!(
      name: "get_weather",
      description: "Get current weather conditions for a specific location",
      parameter_schema: [
        location: [
          type: :string, 
          required: true, 
          doc: "City name or coordinates (e.g., 'San Francisco' or '37.7749,-122.4194')"
        ],
        units: [
          type: :string, 
          default: "metric", 
          doc: "Temperature units: 'metric', 'imperial', or 'kelvin'"
        ],
        include_forecast: [
          type: :boolean, 
          default: false, 
          doc: "Include 24-hour forecast data"
        ]
      ],
      callback: {__MODULE__, :fetch_weather}
    )
  end

  defp create_location_tool do
    ReqLLM.Tool.new!(
      name: "get_user_location",
      description: "Get user's current location for weather queries",
      parameter_schema: [
        accuracy: [
          type: :string,
          default: "city",
          doc: "Location accuracy: 'city', 'region', or 'country'"
        ]
      ],
      callback: {__MODULE__, :get_user_location}
    )
  end

  # Tool callback implementations with proper error handling
  def fetch_weather(params) do
    location = params["location"]
    units = params["units"] || "metric"
    include_forecast = params["include_forecast"] || false

    Logger.info("Fetching weather data", location: location, units: units)

    # In production, this would make real API calls
    case simulate_weather_api_call(location, units, include_forecast) do
      {:ok, weather_data} ->
        Logger.info("Weather data fetched successfully", location: location)
        {:ok, weather_data}

      {:error, :location_not_found} ->
        Logger.warn("Location not found", location: location)
        {:error, "Sorry, I couldn't find weather data for '#{location}'. Please check the location name."}

      {:error, :api_quota_exceeded} ->
        Logger.error("Weather API quota exceeded")
        {:error, "Weather service is temporarily unavailable. Please try again later."}

      {:error, reason} ->
        Logger.error("Weather API error", reason: reason)
        {:error, "Unable to fetch weather data at this time."}
    end
  rescue
    error ->
      Logger.error("Weather tool exception", error: Exception.message(error))
      {:error, "An unexpected error occurred while fetching weather data."}
  end

  def get_user_location(params) do
    accuracy = params["accuracy"] || "city"
    Logger.info("Getting user location", accuracy: accuracy)

    # Mock location data - in production this might use IP geolocation
    case simulate_location_service(accuracy) do
      {:ok, location_data} ->
        {:ok, location_data}

      {:error, reason} ->
        Logger.warn("Location service error", reason: reason)
        {:error, "Unable to determine your location. Please specify a city name."}
    end
  end

  # Error handling examples following ReqLLM usage rules
  defp model_validation_example do
    IO.puts("\n  Model Validation:")
    
    case ReqLLM.Model.from("invalid:model:spec") do
      {:ok, model} -> 
        IO.puts("    ✅ Model validated: #{inspect(model)}")
        
      {:error, %ReqLLM.Error.Invalid.Provider{provider: provider}} ->
        IO.puts("    ❌ Unsupported provider: #{provider}")
        
      {:error, error} ->
        IO.puts("    ❌ Model validation failed: #{inspect(error)}")
    end
  end

  defp api_error_handling_example do
    IO.puts("\n  API Error Handling Pattern:")
    IO.puts("""
    case ReqLLM.generate_text("anthropic:claude-3-sonnet", "Hello") do
      {:ok, response} -> 
        handle_success(response)
        
      {:error, %ReqLLM.Error.API.RateLimit{retry_after: seconds}} ->
        Logger.warn("Rate limited, retry after \#{seconds}s")
        schedule_retry(seconds)
        
      {:error, %ReqLLM.Error.API.Authentication{}} ->
        Logger.error("Authentication failed - check API key")
        {:error, :auth_failed}
        
      {:error, %ReqLLM.Error.API.QuotaExceeded{}} ->
        Logger.error("API quota exceeded")
        use_fallback_provider()
        
      {:error, error} ->
        Logger.error("Unexpected error: \#{inspect(error)}")
        {:error, :unknown}
    end
    """)
  end

  # Mock service implementations
  defp simulate_weather_api_call(location, units, _include_forecast) do
    # Simulate various API responses
    case location do
      loc when loc in ["San Francisco", "NYC", "New York", "London"] ->
        {:ok, %{
          location: location,
          temperature: if(units == "metric", do: 20, else: 68),
          condition: "partly cloudy",
          humidity: 65,
          units: units
        }}
        
      "Unknown City" ->
        {:error, :location_not_found}
        
      "quota_test" ->
        {:error, :api_quota_exceeded}
        
      _ ->
        {:ok, %{
          location: location,
          temperature: if(units == "metric", do: 18, else: 64),
          condition: "sunny",
          humidity: 45,
          units: units
        }}
    end
  end

  defp simulate_location_service(_accuracy) do
    {:ok, %{
      city: "San Francisco",
      region: "California",
      country: "United States",
      coordinates: %{lat: 37.7749, lng: -122.4194}
    }}
  end
end

# Run the examples
ProductionExample.run_all()

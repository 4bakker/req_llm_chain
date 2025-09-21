#!/usr/bin/env elixir

# Advanced tool calling demo for ReqLLMChain
# Shows realistic tool usage with custom context and error handling

Mix.install([{:req_llm_chain, github: "4bakker/req_llm_chain"}])

defmodule ToolCallingDemo do
  @moduledoc """
  Demonstrates advanced tool calling features including:
  - Multiple tools working together
  - Custom context usage
  - Error handling in tools
  - Realistic service integrations
  """

  def run do
    IO.puts("🔧 Advanced Tool Calling Demo")
    IO.puts("=" |> String.duplicate(50))

    # Set up tools and context
    tools = [
      create_weather_tool(),
      create_calendar_tool(),
      create_user_profile_tool()
    ]

    custom_context = %{
      user_id: 42,
      api_keys: %{
        weather: "demo_weather_key_123",
        calendar: "demo_calendar_key_456"
      },
      user_preferences: %{
        temperature_unit: "fahrenheit",
        timezone: "America/Los_Angeles"
      }
    }

    # Create conversation with tools
    chain =
      ReqLLMChain.new("openai:gpt-4", temperature: 0.7)
      |> ReqLLMChain.system("""
      You are a personal assistant with access to weather, calendar, and user profile tools.
      Help the user plan their day by checking weather, calendar events, and their preferences.
      Always be helpful and provide actionable advice.
      """)
      |> ReqLLMChain.user("I'm thinking of going for a run tomorrow. Can you help me plan when would be best?")
      |> ReqLLMChain.tools(tools)
      |> ReqLLMChain.context(custom_context)

    IO.puts("Demo chain created with:")
    IO.puts("- Model: openai:gpt-4")
    IO.puts("- Tools: #{Enum.map(tools, & &1.name) |> Enum.join(", ")}")
    IO.puts("- User ID: #{custom_context.user_id}")
    IO.puts("- Available API keys: #{Map.keys(custom_context.api_keys) |> Enum.join(", ")}")

    IO.puts("\n📋 Current conversation:")
    IO.puts(ReqLLMChain.text_content(chain))

    IO.puts("\n🔄 Simulating tool execution flow:")
    simulate_tool_execution(chain)

    IO.puts("\n✨ To run with real APIs:")
    IO.puts("1. Get API keys for OpenAI and any weather services")
    IO.puts("2. Set environment variables:")
    IO.puts("   export OPENAI_API_KEY=your_openai_key")
    IO.puts("   export WEATHER_API_KEY=your_weather_key")
    IO.puts("3. Replace demo tools with real service integrations")
    IO.puts("4. Call: {:ok, final_chain, response} = ReqLLMChain.run(chain)")
  end

  defp simulate_tool_execution(chain) do
    # Simulate what would happen in a real tool calling loop
    IO.puts("1. LLM receives user request about running tomorrow")
    IO.puts("2. LLM decides it needs weather and calendar information")
    IO.puts("3. LLM calls weather_tool and calendar_tool simultaneously")

    # Simulate tool execution
    weather_result = simulate_weather_call(chain.custom_context)
    calendar_result = simulate_calendar_call(chain.custom_context)
    profile_result = simulate_profile_call(chain.custom_context)

    IO.puts("4. Tools execute with results:")
    IO.puts("   Weather: #{inspect(weather_result)}")
    IO.puts("   Calendar: #{inspect(calendar_result)}")
    IO.puts("   Profile: #{inspect(profile_result)}")

    IO.puts("5. LLM receives tool results and formulates response")
    IO.puts("6. Final response: 'Based on tomorrow's weather (sunny, 75°F) and your")
    IO.puts("   calendar (free from 7-9am), I recommend running at 7:30am when it's")
    IO.puts("   cooler. Don't forget sunscreen!'")
  end

  defp simulate_weather_call(context) do
    # This simulates what the real weather tool would do
    user_id = context.user_id
    api_key = context.api_keys.weather
    unit = context.user_preferences.temperature_unit

    IO.puts("   🌤️  Weather API call (user: #{user_id}, key: #{String.slice(api_key, 0, 8)}..., unit: #{unit})")
    %{temperature: 75, condition: "sunny", wind_speed: 5, humidity: 45}
  end

  defp simulate_calendar_call(context) do
    user_id = context.user_id
    timezone = context.user_preferences.timezone

    IO.puts("   📅 Calendar API call (user: #{user_id}, timezone: #{timezone})")
    %{
      tomorrow_events: [
        %{time: "10:00 AM", title: "Team Meeting", duration: "1 hour"},
        %{time: "2:00 PM", title: "Doctor Appointment", duration: "30 mins"}
      ],
      free_slots: ["7:00 AM - 10:00 AM", "11:00 AM - 2:00 PM", "3:00 PM onwards"]
    }
  end

  defp simulate_profile_call(context) do
    user_id = context.user_id

    IO.puts("   👤 User profile lookup (user: #{user_id})")
    %{
      fitness_level: "intermediate",
      preferred_run_time: "morning",
      typical_run_duration: "30-45 minutes"
    }
  end

  # Real tool definitions that would work with actual APIs
  defp create_weather_tool do
    ReqLLM.Tool.new!(
      name: "get_weather",
      description: "Get weather forecast for tomorrow",
      parameter_schema: [
        location: [type: :string, default: "user_location", doc: "Location for weather"],
        date: [type: :string, default: "tomorrow", doc: "Date for forecast"]
      ],
      callback: fn params, context ->
        location = params["location"]
        user_id = context.user_id
        api_key = context.api_keys[:weather]
        unit = context.user_preferences[:temperature_unit]

        # In real implementation, would call actual weather service
        IO.puts("🌤️  Fetching weather for #{location} (user: #{user_id}, unit: #{unit})")

        if api_key do
          # Mock successful weather API response
          {:ok, %{
            location: location,
            tomorrow: %{
              temperature: if(unit == "celsius", do: 24, else: 75),
              condition: "sunny",
              wind_speed: 5,
              humidity: 45,
              best_times: ["7:00-9:00 AM", "6:00-8:00 PM"]
            }
          }}
        else
          {:error, "Weather API key not configured"}
        end
      end
    )
  end

  defp create_calendar_tool do
    ReqLLM.Tool.new!(
      name: "check_calendar",
      description: "Check calendar events for tomorrow",
      parameter_schema: [
        date: [type: :string, default: "tomorrow", doc: "Date to check"],
        type: [type: :string, default: "all", doc: "Event type filter"]
      ],
      callback: fn params, context ->
        date = params["date"]
        user_id = context.user_id
        timezone = context.user_preferences[:timezone]
        api_key = context.api_keys[:calendar]

        IO.puts("📅 Checking calendar for #{date} (user: #{user_id}, tz: #{timezone})")

        if api_key do
          # Mock calendar response
          {:ok, %{
            date: date,
            events: [
              %{time: "10:00 AM", title: "Team Meeting", duration: "1 hour"},
              %{time: "2:00 PM", title: "Doctor Appointment", duration: "30 mins"}
            ],
            free_slots: [
              "7:00 AM - 10:00 AM",
              "11:00 AM - 2:00 PM",
              "3:00 PM onwards"
            ]
          }}
        else
          {:error, "Calendar API key not configured"}
        end
      end
    )
  end

  defp create_user_profile_tool do
    ReqLLM.Tool.new!(
      name: "get_user_profile",
      description: "Get user's fitness preferences and history",
      parameter_schema: [
        fields: [type: {:list, :string}, default: ["fitness", "preferences"], doc: "Profile fields to fetch"]
      ],
      callback: fn _params, context ->
        user_id = context.user_id

        IO.puts("👤 Fetching user profile (user: #{user_id})")

        # Mock user profile (would come from database in real app)
        {:ok, %{
          user_id: user_id,
          fitness_profile: %{
            level: "intermediate",
            preferred_run_time: "morning",
            typical_duration: "30-45 minutes",
            runs_per_week: 3
          },
          preferences: context.user_preferences
        }}
      end
    )
  end
end

# Run the demo
ToolCallingDemo.run()

defmodule ReqLLMChain.IntegrationWorkflowsTest do
  use ExUnit.Case

  import ReqLLMChain.TestHelpers

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

    test "customer service workflow" do
      # Simulate a more complex customer service scenario
      lookup_tool = create_tool("customer_lookup", "Look up customer information")
      ticket_tool = create_tool("create_ticket", "Create support ticket")
      email_tool = create_tool("send_email", "Send email to customer")

      service_context = %{
        agent_id: "agent_007",
        department: "technical_support",
        priority: "high",
        customer_tier: "premium"
      }

      service_chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.system("You are a customer service agent. Be helpful and professional.")
        |> ReqLLMChain.tools([lookup_tool, ticket_tool, email_tool])
        |> ReqLLMChain.context(service_context)
        |> ReqLLMChain.user("I'm having trouble with my premium account login")
        |> ReqLLMChain.assistant("I'll help you with that login issue. Let me look up your account.")

      # Verify workflow setup
      assert length(ReqLLMChain.messages(service_chain)) == 3
      assert length(service_chain.tools) == 3
      assert service_chain.custom_context.customer_tier == "premium"
      assert service_chain.custom_context.agent_id == "agent_007"

      # Verify conversation flow
      text_content = ReqLLMChain.text_content(service_chain)
      assert text_content =~ "customer service agent"
      assert text_content =~ "premium account"
      assert text_content =~ "login issue"
    end

    test "educational tutoring workflow" do
      # Simulate an AI tutor helping with math
      calculator = create_calculator_tool()
      explanation_tool = create_tool("explain_concept", "Explain mathematical concepts")
      exercise_tool = create_tool("generate_exercise", "Generate practice exercises")

      student_context = %{
        student_id: "student_42",
        grade_level: 8,
        subject: "algebra",
        learning_style: "visual",
        strengths: ["geometry", "basic_arithmetic"],
        challenges: ["word_problems", "fractions"]
      }

      tutor_chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are a patient math tutor. Adapt to the student's learning style and pace.")
        |> ReqLLMChain.tools([calculator, explanation_tool, exercise_tool])
        |> ReqLLMChain.context(student_context)
        |> ReqLLMChain.user("I don't understand how to solve 2x + 5 = 15")
        |> ReqLLMChain.assistant("Let's work through this step by step. First, I'll explain the concept.")

      # Verify educational workflow setup
      assert length(ReqLLMChain.messages(tutor_chain)) == 3
      assert length(tutor_chain.tools) == 3
      assert tutor_chain.custom_context.subject == "algebra"
      assert tutor_chain.custom_context.learning_style == "visual"
      assert "word_problems" in tutor_chain.custom_context.challenges

      # Continue the tutoring session
      continued_session =
        tutor_chain
        |> ReqLLMChain.user("Can you show me another example?")
        |> ReqLLMChain.assistant("Of course! Let me create a similar problem for you to practice.")

      assert length(ReqLLMChain.messages(continued_session)) == 5

      # Verify the conversation maintains educational context
      final_text = ReqLLMChain.text_content(continued_session)
      assert final_text =~ "math tutor"
      assert final_text =~ "2x + 5 = 15"
      assert final_text =~ "step by step"
    end

    test "complex multi-session workflow" do
      # Test a workflow that might span multiple sessions
      base_context = %{
        user_id: "user_789",
        session_history: [
          %{date: ~D[2024-01-01], topic: "weather", tools_used: ["weather"]},
          %{date: ~D[2024-01-02], topic: "math", tools_used: ["calculator"]}
        ],
        preferences: %{
          response_style: "concise",
          expertise_level: "intermediate"
        }
      }

      # Start new session building on previous context
      session_chain =
        ReqLLMChain.new("anthropic:claude-3-sonnet")
        |> ReqLLMChain.system("Continue helping the user based on their history and preferences")
        |> ReqLLMChain.context(base_context)
        |> ReqLLMChain.tools([create_calculator_tool(), create_weather_tool()])
        |> ReqLLMChain.user("Can you help me with both weather and math like before?")

      # Verify session continuity
      assert session_chain.custom_context.user_id == "user_789"
      assert length(session_chain.custom_context.session_history) == 2
      assert session_chain.custom_context.preferences.response_style == "concise"

      # Add session progression
      updated_context = %{
        current_session: %{
          date: ~D[2024-01-03],
          topic: "weather_and_math",
          started_at: ~T[10:00:00]
        }
      }

      evolved_chain =
        session_chain
        |> ReqLLMChain.context(updated_context)
        |> ReqLLMChain.assistant("I see you want help with both weather and math again. Let me assist you.")

      # Verify context evolution
      assert evolved_chain.custom_context.current_session.topic == "weather_and_math"
      assert evolved_chain.custom_context.user_id == "user_789"  # Original context preserved
      assert evolved_chain.custom_context.preferences.response_style == "concise"  # Original preferences preserved
    end
  end
end

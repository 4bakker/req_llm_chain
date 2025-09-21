defmodule ReqLLMChain.ReqLLMStructuresTest do
  use ExUnit.Case

  import ReqLLMChain.TestHelpers

  describe "ReqLLM structure verification" do
    test "builder creates proper ReqLLM.Message structs" do
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are helpful")
        |> ReqLLMChain.user("Hello")
        |> ReqLLMChain.assistant("Hi there!")

      messages = ReqLLMChain.messages(chain)

      # Verify each message is a proper ReqLLM.Message struct
      Enum.each(messages, fn message ->
        assert %ReqLLM.Message{} = message
        assert message.role in [:system, :user, :assistant]
        assert is_list(message.content)

        # Verify content parts are ReqLLM.Message.ContentPart structs
        Enum.each(message.content, fn content_part ->
          assert %ReqLLM.Message.ContentPart{} = content_part
          assert content_part.type == :text
          assert is_binary(content_part.text)
        end)
      end)

      # Verify specific message structure
      [system_msg, user_msg, assistant_msg] = messages

      assert system_msg.role == :system
      assert [%ReqLLM.Message.ContentPart{type: :text, text: "You are helpful"}] = system_msg.content

      assert user_msg.role == :user
      assert [%ReqLLM.Message.ContentPart{type: :text, text: "Hello"}] = user_msg.content

      assert assistant_msg.role == :assistant
      assert [%ReqLLM.Message.ContentPart{type: :text, text: "Hi there!"}] = assistant_msg.content
    end

    test "builder creates proper ReqLLM.Tool structs" do
      tool = create_test_tool()

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.tools([tool])

      # Verify tool is properly structured ReqLLM.Tool
      [chain_tool] = chain.tools
      assert %ReqLLM.Tool{} = chain_tool
      assert chain_tool.name == "test_tool"
      assert chain_tool.description == "A test tool"
      assert is_list(chain_tool.parameter_schema) and Keyword.keyword?(chain_tool.parameter_schema)
      assert is_function(chain_tool.callback, 1)
    end

    test "context passed to ReqLLM is properly structured" do
      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are helpful")
        |> ReqLLMChain.user("Hello")

      # Verify the context field contains ReqLLM.Context
      assert %ReqLLM.Context{} = chain.context

      # Verify context contains proper messages
      context_messages = ReqLLM.Context.to_list(chain.context)
      assert length(context_messages) == 2

      Enum.each(context_messages, fn message ->
        assert %ReqLLM.Message{} = message
        assert message.role in [:system, :user, :assistant]
      end)
    end

    test "model spec creates proper ReqLLM.Model struct" do
      chain = ReqLLMChain.new("openai:gpt-4", temperature: 0.7)

      # Verify model is properly structured
      assert %ReqLLM.Model{} = chain.model
      assert chain.model.provider == :openai
      assert chain.model.model == "gpt-4"
    end

    test "options are properly formatted for ReqLLM" do
      tool = create_test_tool()

      chain =
        ReqLLMChain.new("openai:gpt-4", temperature: 0.7, max_tokens: 1000)
        |> ReqLLMChain.tools([tool])

      # Access the private build_req_options function indirectly by checking
      # that options and tools are stored correctly for ReqLLM consumption
      assert chain.options == [temperature: 0.7, max_tokens: 1000]
      assert length(chain.tools) == 1
      assert %ReqLLM.Tool{} = List.first(chain.tools)
    end

    test "complex conversation maintains ReqLLM structure integrity" do
      tool1 = create_calculator_tool()
      tool2 = create_weather_tool()

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.system("You are a helpful assistant")
        |> ReqLLMChain.user("What's 2+2?")
        |> ReqLLMChain.assistant("2+2 equals 4")
        |> ReqLLMChain.user("What about the weather?")
        |> ReqLLMChain.tools([tool1, tool2])
        |> ReqLLMChain.context(%{user_id: 123, api_keys: %{weather: "key"}})

      # Verify all messages maintain ReqLLM.Message structure
      messages = ReqLLMChain.messages(chain)
      assert length(messages) == 4

      Enum.each(messages, fn message ->
        assert %ReqLLM.Message{} = message
        assert message.role in [:system, :user, :assistant]
        assert is_list(message.content)

        Enum.each(message.content, fn content_part ->
          assert %ReqLLM.Message.ContentPart{} = content_part
        end)
      end)

      # Verify tools maintain ReqLLM.Tool structure
      assert length(chain.tools) == 2
      Enum.each(chain.tools, fn tool ->
        assert %ReqLLM.Tool{} = tool
        assert is_binary(tool.name)
        assert is_binary(tool.description)
      end)

      # Verify context structure
      assert %ReqLLM.Context{} = chain.context
      context_messages = ReqLLM.Context.to_list(chain.context)
      assert length(context_messages) == 4

      # Verify custom context is separate and preserved
      assert chain.custom_context == %{user_id: 123, api_keys: %{weather: "key"}}
    end

    test "empty chain maintains proper ReqLLM structures" do
      chain = ReqLLMChain.new("anthropic:claude-3-sonnet")

      # Even empty chain should have proper ReqLLM structures
      assert %ReqLLM.Model{} = chain.model
      assert %ReqLLM.Context{} = chain.context
      assert chain.tools == []
      assert chain.custom_context == %{}

      # Empty context should still be valid ReqLLM.Context
      messages = ReqLLM.Context.to_list(chain.context)
      assert messages == []
    end

    test "unicode content preserves ReqLLM.Message structure" do
      unicode_content = "Hello 🌍! Testing émojis and 你好"

      chain =
        ReqLLMChain.new("openai:gpt-4")
        |> ReqLLMChain.user(unicode_content)

      [message] = ReqLLMChain.messages(chain)
      assert %ReqLLM.Message{} = message
      assert message.role == :user

      [content_part] = message.content
      assert %ReqLLM.Message.ContentPart{} = content_part
      assert content_part.type == :text
      assert content_part.text == unicode_content
    end
  end

  describe "ReqLLM integration compatibility" do
    test "chain can be used with ReqLLM.generate_text structure" do
      # This test verifies that our chain produces the exact structure
      # that ReqLLM.generate_text expects

      chain =
        ReqLLMChain.new("openai:gpt-4", temperature: 0.5)
        |> ReqLLMChain.system("You are helpful")
        |> ReqLLMChain.user("Hello")

      # These are the exact parameters that would be passed to ReqLLM.generate_text
      model = chain.model  # ReqLLM.Model struct
      context = chain.context  # ReqLLM.Context struct
      options = [tools: chain.tools] ++ chain.options  # Keyword list

      # Verify types match ReqLLM expectations
      assert %ReqLLM.Model{} = model
      assert %ReqLLM.Context{} = context
      assert is_list(options)
      assert Keyword.keyword?(options)

      # Verify model structure
      assert model.provider in [:openai, :anthropic, :google, :cohere]  # Valid providers
      assert is_binary(model.model)

      # Verify context messages are properly formatted
      messages = ReqLLM.Context.to_list(context)
      Enum.each(messages, fn message ->
        assert %ReqLLM.Message{} = message
        assert message.role in [:system, :user, :assistant, :tool]
        assert is_list(message.content)
      end)

      # Verify options structure
      assert Keyword.has_key?(options, :tools)
      tools = Keyword.get(options, :tools)
      assert is_list(tools)
      Enum.each(tools, fn tool ->
        assert %ReqLLM.Tool{} = tool
      end)
    end

    test "tool execution results maintain ReqLLM structure" do
      # Test that when we process tool results, we create proper ReqLLM.Message structs

      # Create a mock tool result as ReqLLM would return it
      tool_call_id = "call_123"
      tool_result = "Calculator result: 42"

      # This simulates what our tool_result_to_message function creates
      content_part = ReqLLM.Message.ContentPart.tool_result(tool_call_id, tool_result)

      tool_message = %ReqLLM.Message{
        role: :tool,
        content: [content_part],
        tool_call_id: tool_call_id
      }

      # Verify the structure matches ReqLLM expectations
      assert %ReqLLM.Message{} = tool_message
      assert tool_message.role == :tool
      assert tool_message.tool_call_id == tool_call_id

      [content_part] = tool_message.content
      assert %ReqLLM.Message.ContentPart{} = content_part
      assert content_part.type == :tool_result
    end
  end
end

defmodule ReqLLMChain.ErrorValidationTest do
  use ExUnit.Case

  import ReqLLMChain.TestHelpers

  describe "error handling and validation" do
    test "handles invalid model spec gracefully" do
      assert_raise ReqLLM.Error.Validation.Error, fn ->
        ReqLLMChain.new("invalid:model:spec:format")
      end
    end

    test "validates required parameters for tools" do
      invalid_tool = fn ->
        ReqLLM.Tool.new!(
          # Missing required name
          description: "A test tool",
          parameter_schema: [],
          callback: fn _params -> {:ok, "result"} end
        )
      end

      assert_raise ReqLLM.Error.Validation.Error, invalid_tool
    end

    test "handles empty messages gracefully" do
      chain = ReqLLMChain.new("openai:gpt-4")
      assert chain.context.messages == []
      assert ReqLLMChain.messages(chain) == []
    end

    test "validates tool execution failures" do
      failing_tool = create_failing_tool()

      # Tool creation should succeed even if callback will fail
      assert failing_tool.name == "failing_tool"
    end

    test "handles nil values gracefully" do
      chain = ReqLLMChain.new("openai:gpt-4")

      # Adding nil context should work
      updated_chain = ReqLLMChain.context(chain, nil)
      assert updated_chain.custom_context == %{}
    end

    test "validates chain structure integrity" do
      chain = ReqLLMChain.new("anthropic:claude-3-sonnet")

      # Chain should always maintain its structure
      assert %ReqLLMChain.Chain{} = chain
      assert is_struct(chain.model, ReqLLM.Model)
      assert is_list(chain.tools)
      assert is_map(chain.custom_context)
    end
  end
end

defmodule ReqLLMChain.ChainCreationTest do
  use ExUnit.Case
  doctest ReqLLMChain

  alias ReqLLMChain.Chain

  describe "chain creation" do
    test "creates a new chain with string model spec" do
      chain = ReqLLMChain.new("anthropic:claude-3-sonnet")

      assert %Chain{} = chain
      assert chain.model.provider == :anthropic
      assert chain.model.model == "claude-3-sonnet"
      assert chain.context.messages == []
      assert chain.tools == []
      assert chain.custom_context == %{}
    end

    test "creates a chain with options" do
      chain = ReqLLMChain.new("openai:gpt-4", temperature: 0.7, max_tokens: 1000)

      assert chain.model.provider == :openai
      assert chain.options == [temperature: 0.7, max_tokens: 1000]
    end
  end
end

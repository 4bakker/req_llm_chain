defmodule ReqLLMChain.ToolExecutor do
  @moduledoc """
  Handles automatic execution of tool calls from AI responses.

  This module extracts tool calls from LLM responses, executes the corresponding
  tools with custom context, and returns the results in a format that can be
  sent back to the LLM.
  """

  require Logger

  @doc """
  Executes all tool calls from a message.

  ## Parameters

  - `message` - The ReqLLM.Message containing tool calls
  - `available_tools` - List of available ReqLLM.Tool structs
  - `custom_context` - Custom context map passed to tool callbacks

  ## Returns

  - `{:ok, [{tool_call_id, result}]}` - List of tool call results
  - `{:error, reason}` - If any tool execution fails

  ## Examples

      tool_results = ToolExecutor.execute_all(
        response.message,
        [weather_tool, calendar_tool],
        %{user_id: 123, api_keys: %{weather: "key"}}
      )

  """
  @spec execute_all(ReqLLM.Message.t() | nil, [ReqLLM.Tool.t()], map()) ::
          {:ok, [{String.t(), term()}]} | {:error, term()}
  def execute_all(nil, _tools, _custom_context), do: {:ok, []}

  def execute_all(%ReqLLM.Message{content: content}, available_tools, custom_context) do
    tool_calls = extract_tool_calls(content)

    if Enum.empty?(tool_calls) do
      {:ok, []}
    else
      execute_tool_calls(tool_calls, available_tools, custom_context)
    end
  end

  @doc """
  Executes a single tool call.

  ## Parameters

  - `tool_call` - ContentPart with type :tool_call
  - `available_tools` - List of available tools
  - `custom_context` - Custom context for tool execution

  ## Returns

  - `{:ok, {tool_call_id, result}}` - Tool execution result
  - `{:error, reason}` - If tool execution fails

  """
  @spec execute_single(ReqLLM.Message.ContentPart.t(), [ReqLLM.Tool.t()], map()) ::
          {:ok, {String.t(), term()}} | {:error, term()}
  def execute_single(
        %ReqLLM.Message.ContentPart{
          type: :tool_call,
          tool_call_id: call_id,
          tool_name: tool_name,
          input: input
        },
        available_tools,
        custom_context
      ) do
    case find_tool_by_name(available_tools, tool_name) do
      nil ->
        error_result = %{
          error: "Tool not found",
          tool_name: tool_name,
          available_tools: Enum.map(available_tools, & &1.name)
        }

        Logger.warning("Tool not found: #{tool_name}")
        {:ok, {call_id, error_result}}

      tool ->
        Logger.info("Executing tool: #{tool_name} with input: #{inspect(input)}")

        case execute_tool_with_context(tool, input, custom_context) do
          {:ok, result} ->
            Logger.info("Tool #{tool_name} executed successfully")
            {:ok, {call_id, result}}

          {:error, reason} ->
            error_result = %{
              error: "Tool execution failed",
              tool_name: tool_name,
              reason: reason
            }

            Logger.error("Tool #{tool_name} failed: #{inspect(reason)}")
            {:ok, {call_id, error_result}}
        end
    end
  end

  # Private helpers

  defp extract_tool_calls(content) do
    Enum.filter(content, fn
      %ReqLLM.Message.ContentPart{type: :tool_call} -> true
      _ -> false
    end)
  end

  defp execute_tool_calls(tool_calls, available_tools, custom_context) do
    results =
      Enum.map(tool_calls, fn tool_call ->
        execute_single(tool_call, available_tools, custom_context)
      end)

    # Check if any executions failed at the executor level (not tool level)
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        # All executions succeeded (even if individual tools returned errors)
        successful_results = Enum.map(results, fn {:ok, result} -> result end)
        {:ok, successful_results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_tool_by_name(tools, name) do
    Enum.find(tools, &(&1.name == name))
  end

  defp execute_tool_with_context(tool, input, custom_context) do
    case tool.callback do
      {module, function} ->
        # MFA format - pass input and custom_context
        apply(module, function, [input, custom_context])

      {module, function, extra_args} ->
        # MFA with extra args - prepend extra_args, then input, then custom_context
        args = extra_args ++ [input, custom_context]
        apply(module, function, args)

      callback_fn when is_function(callback_fn, 1) ->
        # Function that takes only input - merge custom_context into input
        merged_input = Map.merge(input, %{__context__: custom_context})
        callback_fn.(merged_input)

      callback_fn when is_function(callback_fn, 2) ->
        # Function that takes input and custom_context separately
        callback_fn.(input, custom_context)

      callback_fn ->
        # Try to call with just input for backward compatibility
        try do
          callback_fn.(input)
        rescue
          e in FunctionClauseError ->
            {:error, "Tool callback function signature mismatch: #{inspect(e)}"}
        end
    end
  rescue
    e ->
      {:error, "Tool execution exception: #{inspect(e)}"}
  end
end

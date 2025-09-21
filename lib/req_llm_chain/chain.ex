defmodule ReqLLMChain.Chain do
  @moduledoc """
  Core conversation chain implementation.

  This module implements the builder pattern and conversation state management
  for ReqLLM interactions.
  """

  defstruct [
    :model,
    :context,
    :tools,
    :custom_context,
    :options
  ]

  alias ReqLLMChain.ToolExecutor

  @type t :: %__MODULE__{
          model: ReqLLM.Model.t(),
          context: ReqLLM.Context.t(),
          tools: [ReqLLM.Tool.t()],
          custom_context: map(),
          options: keyword()
        }

  @doc """
  Creates a new conversation chain.
  """
  @spec new(ReqLLM.model_spec(), keyword()) :: t()
  def new(model_spec, opts \\ []) do
    model = ReqLLM.Model.from!(model_spec)

    %__MODULE__{
      model: model,
      context: ReqLLM.Context.new([]),
      tools: [],
      custom_context: %{},
      options: opts
    }
  end

  @doc """
  Adds a system message to the conversation.
  """
  @spec system(t(), String.t()) :: t()
  def system(chain, content) when is_binary(content) do
    message = ReqLLM.Context.system(content)
    update_context(chain, message)
  end

  @doc """
  Adds a user message to the conversation.
  """
  @spec user(t(), String.t()) :: t()
  def user(chain, content) when is_binary(content) do
    message = ReqLLM.Context.user(content)
    update_context(chain, message)
  end

  @doc """
  Adds an assistant message to the conversation.
  """
  @spec assistant(t(), String.t()) :: t()
  def assistant(chain, content) when is_binary(content) do
    message = ReqLLM.Context.assistant(content)
    update_context(chain, message)
  end

  @doc """
  Adds tools to the conversation.
  """
  @spec tools(t(), [ReqLLM.Tool.t()]) :: t()
  def tools(chain, tool_list) when is_list(tool_list) do
    updated_tools = chain.tools ++ tool_list
    %{chain | tools: updated_tools}
  end

  @doc """
  Adds custom context data available to tools.
  Merges with existing custom context.
  """
  @spec context(t(), map() | nil) :: t()
  def context(chain, custom_context) when is_map(custom_context) do
    merged_context = Map.merge(chain.custom_context, custom_context)
    %{chain | custom_context: merged_context}
  end

  def context(chain, nil) do
    %{chain | custom_context: %{}}
  end

  @doc """
  Runs the conversation once.
  """
  @spec run(t()) :: {:ok, t(), ReqLLM.Response.t()} | {:error, term()}
  def run(chain) do
    case ReqLLM.generate_text(chain.model, chain.context, build_req_options(chain)) do
      {:ok, response} ->
        updated_chain = %{chain | context: response.context}
        {:ok, updated_chain, response}

      error ->
        error
    end
  end

  @doc """
  Runs the conversation with automatic tool calling loops.
  """
  @spec run_until_done(t(), pos_integer()) :: {:ok, t(), ReqLLM.Response.t()} | {:error, term()}
  def run_until_done(chain, max_iterations \\ 10)

  def run_until_done(_chain, 0) do
    {:error, :max_iterations_reached}
  end

  def run_until_done(chain, iterations_left) do
    case run(chain) do
      {:ok, updated_chain, response} ->
        if has_tool_calls?(response.message) do
          # Execute tools and continue the loop
          case execute_tool_calls(updated_chain, response, chain.custom_context) do
            {:ok, chain_with_results} ->
              run_until_done(chain_with_results, iterations_left - 1)

            error ->
              error
          end
        else
          # No tool calls - conversation is complete
          {:ok, updated_chain, response}
        end

      error ->
        error
    end
  end

  @doc """
  Streams the conversation response.
  """
  @spec stream(t()) :: {:ok, t(), Enumerable.t()} | {:error, term()}
  def stream(chain) do
    stream_options = Keyword.put(build_req_options(chain), :stream, true)

    case ReqLLM.stream_text(chain.model, chain.context, stream_options) do
      {:ok, response} ->
        updated_chain = %{chain | context: response.context}
        {:ok, updated_chain, response.stream}

      error ->
        error
    end
  end

  @doc """
  Extracts text content from the conversation.
  """
  @spec text_content(t()) :: String.t()
  def text_content(chain) do
    chain.context
    |> ReqLLM.Context.to_list()
    |> Enum.map(&extract_message_text/1)
    |> Enum.join("\n\n")
  end

  @doc """
  Gets the current conversation messages.
  """
  @spec messages(t()) :: [ReqLLM.Message.t()]
  def messages(chain) do
    ReqLLM.Context.to_list(chain.context)
  end

  # Private helpers

  defp update_context(chain, message) do
    current_messages = ReqLLM.Context.to_list(chain.context)
    new_context = ReqLLM.Context.new(current_messages ++ [message])
    %{chain | context: new_context}
  end

  defp build_req_options(chain) do
    base_options = [tools: chain.tools]
    Keyword.merge(base_options, chain.options)
  end

  defp has_tool_calls?(nil), do: false

  defp has_tool_calls?(%ReqLLM.Message{content: content}) do
    Enum.any?(content, fn
      %ReqLLM.Message.ContentPart{type: :tool_call} -> true
      _ -> false
    end)
  end

  defp execute_tool_calls(chain, response, custom_context) do
    case ToolExecutor.execute_all(response.message, chain.tools, custom_context) do
      {:ok, tool_results} ->
        # Add tool results as new messages to the conversation
        results_as_messages = Enum.map(tool_results, &tool_result_to_message/1)
        current_messages = ReqLLM.Context.to_list(chain.context)
        new_context = ReqLLM.Context.new(current_messages ++ results_as_messages)

        {:ok, %{chain | context: new_context}}

      error ->
        error
    end
  end

  defp tool_result_to_message({tool_call_id, result}) do
    content_part = ReqLLM.Message.ContentPart.tool_result(tool_call_id, result)

    %ReqLLM.Message{
      role: :tool,
      content: [content_part],
      tool_call_id: tool_call_id
    }
  end

  defp extract_message_text(%ReqLLM.Message{role: role, content: content}) do
    text_parts =
      content
      |> Enum.filter(&(&1.type == :text))
      |> Enum.map(& &1.text)
      |> Enum.join(" ")

    case role do
      :system -> "[SYSTEM] #{text_parts}"
      :user -> "[USER] #{text_parts}"
      :assistant -> "[ASSISTANT] #{text_parts}"
      :tool -> "[TOOL] #{text_parts}"
    end
  end
end

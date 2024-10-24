defmodule Llm.Session do
  @moduledoc """
  Maintains stateful conversations with LLM services using Agents.
  Tracks message history and handles communication with different LLM clients.
  """

  @type message :: %{role: String.t(), content: String.t()}
  @type history :: [message()]
  @type client :: module()
  @type state :: %{
          client: client(),
          client_opts: keyword(),
          history: history()
        }

  @doc """
  Starts a new LLM session with the specified client and options.

  ## Examples
      {:ok, pid} = Llm.Session.start_link(Llm.Client.Claude, max_tokens: 2048)
  """
  @spec start_link(client(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(client, opts \\ []) when is_atom(client) and is_list(opts) do
    initial_state = %{
      client: client,
      client_opts: opts,
      history: []
    }

    Agent.start_link(fn -> initial_state end)
  end

  @doc """
  Sends a message to the LLM and receives a response.
  Updates the session history with both the user message and the assistant's response.

  ## Examples
      {:ok, response} = Llm.Session.send_message(pid, "What is the capital of France?")
  """
  @spec send_message(pid(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def send_message(pid, content) when is_pid(pid) and is_binary(content) do
    Agent.get_and_update(pid, fn state ->
      # Create user message
      user_message = %{role: "user", content: content}

      # Get full message history including the new message
      messages = state.history ++ [user_message]

      # Send to LLM client
      case state.client.chat(messages, state.client_opts) do
        {:ok, response} ->
          # Extract response content using client-specific extractor
          content = state.client.extract_response(response)

          # Create assistant message
          assistant_message = %{
            role: "assistant",
            content: content
          }

          # Update state with both messages
          new_state = %{state | history: messages ++ [assistant_message]}

          {{:ok, content}, new_state}

        {:error, status_code, body} ->
          {{:error, {status_code, body}}, state}

        {:error, reason} ->
          {{:error, reason}, state}
      end
    end)
  end

  @doc """
  Retrieves the full message history from the session.

  ## Examples
      history = Llm.Session.get_history(pid)
  """
  @spec get_history(pid()) :: history()
  def get_history(pid) when is_pid(pid) do
    Agent.get(pid, fn state -> state.history end)
  end

  @doc """
  Stops the session and releases all resources.

  ## Examples
      :ok = Llm.Session.stop(pid)
  """
  @spec stop(pid()) :: :ok
  def stop(pid) when is_pid(pid) do
    Agent.stop(pid)
  end
end


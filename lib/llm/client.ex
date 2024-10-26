defmodule Llm.Client do
  @moduledoc """
  Represents a configured LLM client with its specific options.
  """

  @type t :: %__MODULE__{
          implementation: module(),
          options: map()
        }

  defstruct [:implementation, :options]

  @doc """
  Creates a new client configuration from a module and options.

  ## Examples
      iex> Llm.Client.new(Llm.Client.Claude)
      %Llm.Client{implementation: Llm.Client.Claude, options: %{}
      
      iex> Llm.Client.new(Llm.Client.Claude, temperature: 0.7)
      %Llm.Client{implementation: Llm.Client.Claude, options: %{temperature: 0.7}}
  """
  @spec new(module(), keyword()) :: t()
  def new(implementation, options \\ []) when is_atom(implementation) and is_list(options) do
    processed_options = implementation.process_options(options)
    %__MODULE__{implementation: implementation, options: processed_options}
  end

  @doc """
  Returns a display name for the client configuration that includes relevant parameters.
  Delegates to the implementation module's display_name/1 function.
  """
  @spec display_name(t()) :: String.t()
  def display_name(%__MODULE__{} = client) do
    client.implementation.display_name(client.options)
  end

  @doc """
  Processes chat messages using the configured client and options.
  """
  @spec chat(t(), list()) ::
          {:ok, map()}
          | {:error, pos_integer(), map()}
          | {:error, term()}
  def chat(%__MODULE__{} = client, messages) do
    client.implementation.chat(messages, client.options)
  end
end

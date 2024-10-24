defmodule Llm.Client.Behavior do
  @moduledoc false

  @type token_usage :: %{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer()
        }

  @type pricing :: %{
          required(:input) => float(),
          required(:output) => float()
        }

  @callback base_url() :: String.t()
  @callback request_headers() :: [{String.t(), String.t()}]
  @callback option_processors() :: %{atom() => (term(), map() -> map())}
  @callback extract_response(map()) :: String.t()
  @callback extract_usage(map()) :: token_usage()
  @callback pricing_table() :: %{String.t() => pricing()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Llm.Client.Behavior
      use HTTPoison.Base

      def process_url(url), do: base_url() <> url

      def process_request_headers(headers) do
        request_headers() ++ headers
      end

      def process_response_body(body) do
        Jason.decode!(body)
      end

      # Default implementation that can be overridden
      def request_endpoint, do: "/chat/completions"
      defoverridable request_endpoint: 0

      def calculate_cost(model, usage) do
        pricing = pricing_table()[model]

        if pricing do
          %{input: input_price, output: output_price} = pricing
          input_cost = usage.input_tokens / 1_000_000 * input_price
          output_cost = usage.output_tokens / 1_000_000 * output_price
          input_cost + output_cost
        else
          raise "Unknown model: #{model}"
        end
      end

      def chat(messages, opts \\ []) do
        # Convert initial opts to map with messages
        initial_opts =
          opts
          |> Map.new()
          |> Map.put(:messages, messages)

        # Process all options through processors
        processed_opts =
          option_processors()
          |> Enum.reduce(initial_opts, fn {key, processor}, acc ->
            value = Map.get(acc, key)
            processor.(value, acc)
          end)

        body = Jason.encode!(processed_opts)

        case post(request_endpoint(), body) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            {:ok, body}

          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            {:error, status_code, body}

          {:error, %HTTPoison.Error{reason: reason}} ->
            {:error, reason}
        end
      end
    end
  end
end

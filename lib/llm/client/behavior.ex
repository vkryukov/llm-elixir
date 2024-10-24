defmodule Llm.Client.Behavior do
  @callback base_url() :: String.t()
  @callback request_headers() :: [{String.t(), String.t()}]
  @callback option_processors() :: %{atom() => (term(), map() -> map())}
  @callback request_endpoint() :: String.t()
  @optional_callback request_endpoint: 0

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

      def request_endpoint, do: "/chat/completions"
    end
  end
end

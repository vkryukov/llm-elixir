defmodule Llm.Client.Claude do
  use HTTPoison.Base

  @base_url "https://api.anthropic.com"
  @api_version "2023-06-01"
  @default_model "claude-3-haiku-20240307"
  @default_max_tokens 1024

  def process_url(url) do
    @base_url <> url
  end

  def process_request_headers(headers) do
    api_key = System.get_env("ANTHROPIC_API_KEY")

    [
      {"X-API-Key", api_key},
      {"anthropic-version", @api_version},
      {"Content-Type", "application/json"}
      | headers
    ]
  end

  def process_response_body(body) do
    Jason.decode!(body)
  end

  def chat(messages, opts \\ []) do
    url = "/v1/messages"
    model = opts |> Keyword.get(:model, @default_model) |> expand_model_name()
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)

    body =
      Jason.encode!(%{
        model: model,
        messages: messages,
        max_tokens: max_tokens
      })

    case post(url, body) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, status_code, body}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp expand_model_name(model) do
    case model do
      "opus" -> "claude-3-opus-20240229"
      "opus3" -> "claude-3-opus-20240229"
      "sonnet" -> "claude-3-5-sonnet-20240620"
      "sonnet35" -> "claude-3-5-sonnet-20240620"
      "sonnet3" -> "claude-3-sonnet-20240229"
      "haiku" -> "claude-3-haiku-20240307"
      "haiku3" -> "claude-3-haiku-20240307"
      # Return the original input if no match is found
      _ -> model
    end
  end

  def stream_chat(messages, model \\ "claude-3-opus-20240229") do
    url = "/v1/messages"

    body =
      Jason.encode!(%{
        model: model,
        messages: messages,
        stream: true
      })

    Stream.resource(
      fn ->
        HTTPoison.post!(url, body, process_request_headers([]), stream_to: self(), async: :once)
      end,
      fn %HTTPoison.AsyncResponse{id: id} = resp ->
        receive do
          %HTTPoison.AsyncStatus{id: ^id, code: 200} ->
            HTTPoison.stream_next(resp)
            {[], resp}

          %HTTPoison.AsyncHeaders{id: ^id, headers: _headers} ->
            HTTPoison.stream_next(resp)
            {[], resp}

          %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
            HTTPoison.stream_next(resp)

            case Jason.decode(chunk) do
              {:ok, decoded} -> {[decoded], resp}
              _ -> {[], resp}
            end

          %HTTPoison.AsyncEnd{id: ^id} ->
            {:halt, resp}
        end
      end,
      fn _resp -> :ok end
    )
  end
end

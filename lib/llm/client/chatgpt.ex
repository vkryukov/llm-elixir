defmodule Llm.Client.ChatGpt do
  use HTTPoison.Base

  @base_url "https://api.openai.com/v1"
  @default_model "gpt-4o-mini"
  @default_max_tokens 1024

  def process_url(url) do
    @base_url <> url
  end

  def process_request_headers(headers) do
    api_key = System.get_env("OPENAI_API_KEY")

    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
      | headers
    ]
  end

  def process_response_body(body) do
    Jason.decode!(body)
  end

  def chat(messages, opts \\ []) do
    url = "/chat/completions"
    model = opts |> Keyword.get(:model, @default_model) |> expand_model_name()
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)

    body =
      Jason.encode!(%{
        model: model,
        messages: messages,
        max_completion_tokens: max_tokens
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
      "4o-mini" -> "gpt-4o-mini"
      "4o" -> "gpt-4o"
      "o1" -> "o1-preview"
      # Return the original input if no match is found
      _ -> model
    end
  end
end

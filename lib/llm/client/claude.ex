defmodule Llm.Client.Claude do
  use Llm.Client.Behavior
  alias Llm.Client.OptionHelpers, as: OH

  @base_url "https://api.anthropic.com"
  @api_version "2023-06-01"
  @default_model "claude-3-haiku-20240307"
  @default_max_tokens 1024

  @impl true
  def base_url, do: @base_url

  @impl true
  def request_headers do
    api_key = System.get_env("ANTHROPIC_API_KEY")

    [
      {"X-API-Key", api_key},
      {"anthropic-version", @api_version},
      {"Content-Type", "application/json"}
    ]
  end

  @impl true
  def option_processors do
    %{
      model:
        OH.compose([
          OH.set_default(:model, @default_model),
          OH.transform_value(:model, &expand_model_name/1)
        ]),
      max_tokens: OH.set_default(:max_tokens, @default_max_tokens)
    }
  end

  @impl true
  def extract_response(response) do
    case response do
      %{"content" => [%{"text" => text} | _]} -> text
      _ -> raise "Unexpected response format from Claude API"
    end
  end

  @impl true
  def extract_usage(response) do
    case response do
      %{"usage" => %{"input_tokens" => input, "output_tokens" => output}} ->
        %{input_tokens: input, output_tokens: output}

      _ ->
        raise "Unable to extract token usage from Claude API response"
    end
  end

  @impl true
  def pricing_table do
    %{
      "claude-3-opus-20240229" => %{input: 15.00, output: 75.00},
      "claude-3-5-sonnet-20241022" => %{input: 3.00, output: 15.00},
      "claude-3-haiku-20240307" => %{input: 0.25, output: 1.25}
    }
  end

  def request_endpoint, do: "/v1/messages"

  defp expand_model_name(model) do
    case model do
      "opus" -> "claude-3-opus-20240229"
      "sonnet" -> "claude-3-5-sonnet-20241022"
      "haiku" -> "claude-3-haiku-20240307"
      _ -> model
    end
  end
end

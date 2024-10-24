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
      # No explicit system processor needed - it will be passed through as-is
    }
  end

  def request_endpoint, do: "/v1/messages"

  defp expand_model_name(model) do
    case model do
      "opus" -> "claude-3-opus-20240229"
      "opus3" -> "claude-3-opus-20240229"
      "sonnet" -> "claude-3-5-sonnet-20240620"
      "sonnet35" -> "claude-3-5-sonnet-20240620"
      "sonnet3" -> "claude-3-sonnet-20240229"
      "haiku" -> "claude-3-haiku-20240307"
      "haiku3" -> "claude-3-haiku-20240307"
      _ -> model
    end
  end
end


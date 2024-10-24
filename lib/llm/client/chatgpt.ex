defmodule Llm.Client.ChatGpt do
  use Llm.Client.Behavior
  alias Llm.Client.OptionHelpers, as: OH

  @base_url "https://api.openai.com/v1"
  @default_model "gpt-4o-mini"
  @default_max_tokens 1024

  @impl true
  def base_url, do: @base_url

  @impl true
  def request_headers do
    api_key = System.get_env("OPENAI_API_KEY")

    [
      {"Authorization", "Bearer #{api_key}"},
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
      max_tokens:
        OH.compose([
          OH.rename_key(:max_tokens, :max_completion_tokens),
          OH.set_default(:max_completion_tokens, @default_max_tokens)
        ]),
      system: fn value, opts ->
        case value do
          nil ->
            opts

          system ->
            current_messages = Map.get(opts, :messages, [])
            system_message = [%{role: "system", content: system}]
            Map.put(opts, :messages, system_message ++ current_messages) |> Map.delete(:system)
        end
      end
    }
  end

  @impl true
  def extract_response(response) do
    case response do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} -> content
      _ -> raise "Unexpected response format from ChatGPT API"
    end
  end

  defp expand_model_name(model) do
    case model do
      "4o-mini" -> "gpt-4o-mini"
      "4o" -> "gpt-4o"
      "o1" -> "o1-preview"
      _ -> model
    end
  end
end

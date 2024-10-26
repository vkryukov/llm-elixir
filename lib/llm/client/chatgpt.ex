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

  @impl true
  def extract_usage(response) do
    case response do
      %{"usage" => %{"prompt_tokens" => input, "completion_tokens" => output}} ->
        %{input_tokens: input, output_tokens: output}

      _ ->
        raise "Unable to extract token usage from ChatGPT API response"
    end
  end

  @impl true
  def pricing_table do
    %{
      "gpt-4o" => %{input: 2.50, output: 10.00},
      "gpt-4o-mini" => %{input: 0.15, output: 0.60},
      "o1-preview" => %{input: 15.00, output: 60.00}
    }
  end

  defp expand_model_name(model) do
    case model do
      "4o-mini" -> "gpt-4o-mini"
      "4o" -> "gpt-4o"
      "o1" -> "o1-preview"
      _ -> model
    end
  end

  @impl true
  def display_name(opts) do
    model = Keyword.get(opts, :model, @default_model)

    # Extract just the model variant for cleaner display
    model_variant =
      case model do
        "gpt-4o-mini" -> "4o-mini"
        "gpt-40" -> "4o"
        "o1-preview" -> "o1"
        _ -> model
      end

    "ChatGPT(#{model_variant})"
  end
end

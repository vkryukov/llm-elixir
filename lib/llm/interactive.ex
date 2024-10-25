defmodule Llm.Interactive do
  @moduledoc """
  Provides an interactive chat interface for comparing multiple LLM sessions.
  Handles user input, displays responses from different models, and tracks costs.
  """

  @prompt "> "
  @cost_label_color IO.ANSI.yellow()
  @reset IO.ANSI.reset()

  # Define a list of colors for different models
  @model_colors [
    IO.ANSI.cyan(),
    IO.ANSI.green(),
    IO.ANSI.magenta(),
    IO.ANSI.blue(),
    IO.ANSI.light_cyan(),
    IO.ANSI.light_green()
  ]

  @type model_config :: module() | [module() | keyword()]
  @type session_info :: %{
          pid: pid(),
          name: String.t(),
          color: String.t(),
          config: keyword()
        }

  @doc """
  Starts a new interactive chat session with multiple LLM clients.
  Each client can be specified either as a module or as a list containing the module and options.

  ## Examples
      Llm.Interactive.start([Llm.Client.Claude, model: "opus"], 
                          Llm.Client.ChatGpt, 
                          [Llm.Client.Claude, model: "haiku"])
  """
  @spec start([model_config()] | model_config()) :: :ok
  def start(configs) when is_list(configs) do
    sessions = init_sessions(List.wrap(configs))
    IO.puts("\nChat session started with #{length(sessions)} models.")
    IO.puts("Type your messages and press Enter. Type /quit to exit.\n")
    chat_loop(sessions)
  end

  def start(config), do: start([config])

  @doc """
  Initializes sessions for each model configuration.
  """
  @spec init_sessions([model_config()]) :: [session_info()]
  defp init_sessions(configs) do
    configs
    |> Enum.with_index()
    |> Enum.map(fn {config, index} ->
      {module, opts} = parse_config(config)
      {:ok, pid} = Llm.Session.start_link(module, opts)

      %{
        pid: pid,
        name: get_model_name(module, opts),
        color: Enum.at(@model_colors, index, List.last(@model_colors)),
        config: opts
      }
    end)
  end

  @doc """
  Parses a model configuration into a tuple of {module, opts}.
  """
  @spec parse_config(model_config()) :: {module(), keyword()}
  defp parse_config(config) when is_atom(config), do: {config, []}
  defp parse_config([module | opts]) when is_atom(module), do: {module, opts}

  @doc """
  Generates a display name for the model based on its configuration.
  """
  @spec get_model_name(module(), keyword()) :: String.t()
  defp get_model_name(module, opts) do
    base_name = module |> Module.split() |> List.last()
    model = opts[:model]
    if model, do: "#{base_name}(#{model})", else: base_name
  end

  @doc """
  Maintains the chat loop, processing user input and displaying responses from all models.
  """
  @spec chat_loop([session_info()]) :: :ok
  defp chat_loop(sessions) do
    IO.write(@prompt)

    case IO.gets("") do
      :eof ->
        cleanup_sessions(sessions)
        IO.puts("\nChat session ended.")

      {:error, reason} ->
        IO.puts("\nError: #{inspect(reason)}")
        cleanup_sessions(sessions)

      input ->
        input = String.trim(input)

        case input do
          "" ->
            chat_loop(sessions)

          "/quit" ->
            cleanup_sessions(sessions)
            IO.puts("\nChat session ended.")

          _ ->
            responses = get_all_responses(sessions, input)
            display_responses(responses)
            display_costs(responses)
            chat_loop(sessions)
        end
    end
  end

  @doc """
  Gets responses from all models for the given input.
  """
  @spec get_all_responses([session_info()], String.t()) :: [
          {session_info(), {:ok, String.t()} | {:error, term()}}
        ]
  defp get_all_responses(sessions, input) do
    Enum.map(sessions, fn session ->
      response = Llm.Session.send_message(session.pid, input)
      {session, response}
    end)
  end

  @doc """
  Displays responses from all models with appropriate formatting and colors.
  """
  @spec display_responses([{session_info(), {:ok, String.t()} | {:error, term()}}]) :: :ok
  defp display_responses(responses) do
    IO.puts("")

    Enum.each(responses, fn {session, response} ->
      case response do
        {:ok, content} ->
          IO.puts("#{session.color}[#{session.name}]#{@reset}")
          IO.puts("#{session.color}#{format_response(content)}#{@reset}")
          IO.puts("")

        {:error, reason} ->
          IO.puts("#{session.color}[#{session.name}] Error: #{inspect(reason)}#{@reset}\n")
      end
    end)
  end

  @doc """
  Displays costs for all models using their respective colors.
  """
  @spec display_costs([{session_info(), {:ok, String.t()} | {:error, term()}}]) :: :ok
  defp display_costs(responses) do
    IO.puts("#{@cost_label_color}Cost breakdown:#{@reset}")

    Enum.each(responses, fn {session, _} ->
      case Llm.Session.get_latest_cost(session.pid) do
        {:ok, latest_cost} ->
          total_cost = Llm.Session.get_total_cost(session.pid)

          IO.puts(
            "#{session.color}[#{session.name}] Last: #{format_cost(latest_cost)} | " <>
              "Total: #{format_cost(total_cost)}#{@reset}"
          )

        _ ->
          IO.puts("#{session.color}[#{session.name}] Cost calculation error#{@reset}")
      end
    end)

    IO.puts("")
  end

  @doc """
  Cleans up all active sessions.
  """
  @spec cleanup_sessions([session_info()]) :: :ok
  defp cleanup_sessions(sessions) do
    Enum.each(sessions, fn session -> Llm.Session.stop(session.pid) end)
  end

  # Text formatting helpers remain the same as in the previous version
  defp format_response(text) do
    text
    |> String.split("\n\n")
    |> Enum.map(&wrap_text/1)
    |> Enum.join("\n\n")
  end

  defp wrap_text(text) do
    text
    |> String.split("\n")
    |> Enum.map(fn line ->
      {indent, content} = extract_indent(line)
      wrapped = wrap_line(content, 80 - String.length(indent))
      Enum.map(wrapped, &(indent <> &1))
    end)
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp extract_indent(line) do
    case Regex.run(~r/^(\s*)(.*)$/, line) do
      [_, indent, content] -> {indent, content}
      _ -> {"", line}
    end
  end

  defp wrap_line(text, width) do
    words = String.split(text, " ")
    wrap_words(words, width, [], "")
  end

  defp wrap_words([], _width, lines, current) do
    Enum.reverse([String.trim(current) | lines])
  end

  defp wrap_words([word | rest], width, lines, current) do
    new_line = current <> if(current == "", do: "", else: " ") <> word

    if String.length(new_line) > width and current != "" do
      wrap_words([word | rest], width, [String.trim(current) | lines], "")
    else
      wrap_words(rest, width, lines, new_line)
    end
  end

  defp format_cost(cost) do
    cents = round(cost * 100)
    if cents == 0, do: "0¢", else: "#{cents}¢"
  end
end


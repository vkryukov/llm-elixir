defmodule Llm.Interactive do
  @moduledoc """
  Manages multiple LLM sessions, handles user interaction, and coordinates
  responses and cost tracking.
  """

  alias Llm.Display
  alias Llm.Client

  @prompt "> "

  # Define model-specific colors for up to 6 concurrent models
  @model_colors [
    IO.ANSI.cyan(),
    IO.ANSI.green(),
    IO.ANSI.magenta(),
    IO.ANSI.blue(),
    IO.ANSI.light_cyan(),
    IO.ANSI.light_green()
  ]

  @type client_config :: module() | {module(), keyword()}
  @type session_info :: %{
          pid: pid(),
          client: Client.t(),
          display: Display.color_scheme()
        }

  @doc """
  Starts a new interactive chat session with multiple LLM clients.
  Accepts either module names or {module, options} tuples.

  ## Examples
      # Single client with default options
      Interactive.start(Llm.Client.Claude)

      # Multiple clients with mixed configurations
      Interactive.start([
        Llm.Client.Claude,
        {Llm.Client.Claude, [model: "opus", temperature: 0.7]},
        {Llm.Client.ChatGpt, [model: "4o"]}
      ])
  """
  @spec start([client_config()] | client_config()) :: :ok
  def start(configs) when is_list(configs) do
    sessions = init_sessions(configs)
    display = Display.new()

    Display.display_labeled(
      "System",
      "Chat session started with #{length(sessions)} models.",
      display
    )

    Display.display_labeled(
      "System",
      "Type your messages and press Enter. Type /quit to exit.",
      display
    )

    chat_loop(sessions, display)
  end

  def start(config), do: start([config])

  # Session management functions
  defp init_sessions(configs) do
    configs
    |> Enum.with_index()
    |> Enum.map(fn {config, index} ->
      client = create_client(config)
      {:ok, pid} = Llm.Session.start_link(client)
      color = Enum.at(@model_colors, index, List.last(@model_colors))

      %{
        pid: pid,
        client: client,
        display: Display.new(%{text: color, label: color})
      }
    end)
  end

  defp create_client(module) when is_atom(module), do: Client.new(module)
  defp create_client({module, opts}) when is_atom(module), do: Client.new(module, opts)

  # Chat loop and response handling
  defp chat_loop(sessions, display) do
    IO.write(@prompt)

    case IO.gets("") do
      :eof ->
        cleanup_sessions(sessions)
        Display.display_labeled("System", "Chat session ended.", display)

      {:error, reason} ->
        Display.display_error("System", reason, display)
        cleanup_sessions(sessions)

      input ->
        input = String.trim(input)

        case input do
          "" ->
            chat_loop(sessions, display)

          "/quit" ->
            cleanup_sessions(sessions)
            Display.display_labeled("System", "Chat session ended.", display)

          _ ->
            responses = get_all_responses(sessions, input)
            display_responses(responses)
            display_costs(responses, display)
            chat_loop(sessions, display)
        end
    end
  end

  defp get_all_responses(sessions, input) do
    Enum.map(sessions, fn session ->
      response = Llm.Session.send_message(session.pid, input)
      {session, response}
    end)
  end

  defp display_responses(responses) do
    Enum.each(responses, fn {session, response} ->
      name = Client.display_name(session.client)

      case response do
        {:ok, content} ->
          Display.display_block(name, content, session.display)

        {:error, reason} ->
          Display.display_error(name, reason, session.display)
      end
    end)
  end

  defp display_costs(responses, system_display) do
    Display.display_labeled("Costs", "", system_display)

    Enum.each(responses, fn {session, _} ->
      name = Client.display_name(session.client)

      case Llm.Session.get_latest_cost(session.pid) do
        {:ok, latest_cost} ->
          total_cost = Llm.Session.get_total_cost(session.pid)
          cost_text = "Last: #{format_cost(latest_cost)} | Total: #{format_cost(total_cost)}"
          Display.display_labeled(name, cost_text, session.display)

        _ ->
          Display.display_error(name, "Cost calculation error", session.display)
      end
    end)

    IO.puts("")
  end

  defp cleanup_sessions(sessions) do
    Enum.each(sessions, fn session -> Llm.Session.stop(session.pid) end)
  end

  defp format_cost(cost) do
    cents = round(cost * 100)
    if cents == 0, do: "0¢", else: "#{cents}¢"
  end
end


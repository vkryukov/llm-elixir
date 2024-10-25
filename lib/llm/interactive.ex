defmodule Llm.Interactive do
  @moduledoc """
  Provides an interactive chat interface for LLM sessions.
  Handles user input, displays responses, and tracks costs.
  """

  @prompt "> "
  @assistant_color IO.ANSI.cyan()
  @cost_color IO.ANSI.yellow()
  @reset IO.ANSI.reset()
  @line_width 100

  @doc """
  Starts a new interactive chat session with the specified LLM client and options.

  ## Examples
      Llm.Interactive.start(Llm.Client.Claude)
      Llm.Interactive.start(Llm.Client.Claude, max_tokens: 2048)
  """
  @spec start(module(), keyword()) :: :ok
  def start(client, opts \\ []) do
    {:ok, pid} = Llm.Session.start_link(client, opts)

    IO.puts(
      "Chat session started. Type your messages and press Enter. Press Ctrl+C twice to exit.\n"
    )

    chat_loop(pid)
  end

  @doc """
  Maintains the chat loop, processing user input and displaying responses.
  """
  @spec chat_loop(pid()) :: :ok
  defp chat_loop(pid) do
    IO.write(@prompt)

    case IO.gets("") do
      :eof ->
        IO.puts("\nChat session ended.")
        Llm.Session.stop(pid)
        :ok

      {:error, reason} ->
        IO.puts("\nError: #{inspect(reason)}")
        Llm.Session.stop(pid)
        :ok

      input ->
        input = String.trim(input)

        case input do
          "" ->
            chat_loop(pid)

          "/quit" ->
            IO.puts("\nChat session ended.")
            Llm.Session.stop(pid)
            :ok

          _ ->
            case Llm.Session.send_message(pid, input) do
              {:ok, response} ->
                # Print the response with formatting
                IO.puts("\n#{@assistant_color}#{format_response(response)}#{@reset}\n")

                # Get and display costs
                {:ok, latest_cost} = Llm.Session.get_latest_cost(pid)
                total_cost = Llm.Session.get_total_cost(pid)

                IO.puts(
                  "#{@cost_color}Last response cost: #{format_cost(latest_cost)} | " <>
                    "Total session cost: #{format_cost(total_cost)}#{@reset}\n"
                )

                chat_loop(pid)

              {:error, reason} ->
                IO.puts("\nError: #{inspect(reason)}")
                chat_loop(pid)
            end
        end
    end
  end

  @doc """
  Formats the response text by wrapping long lines and adding proper indentation.
  """
  @spec format_response(String.t()) :: String.t()
  defp format_response(text) do
    # Split text into paragraphs and wrap each one
    text
    |> String.split("\n\n")
    |> Enum.map(&wrap_text/1)
    |> Enum.join("\n\n")
  end

  @doc """
  Wraps text at @line_width characters while preserving existing line breaks and indentation.
  """
  @spec wrap_text(String.t()) :: String.t()
  defp wrap_text(text) do
    text
    |> String.split("\n")
    |> Enum.map(fn line ->
      # Preserve leading whitespace
      {indent, content} = extract_indent(line)
      wrapped = wrap_line(content, @line_width - String.length(indent))
      Enum.map(wrapped, &(indent <> &1))
    end)
    |> List.flatten()
    |> Enum.join("\n")
  end

  @doc """
  Extracts leading whitespace from a line of text.
  Returns a tuple of {indent, content}.
  """
  @spec extract_indent(String.t()) :: {String.t(), String.t()}
  defp extract_indent(line) do
    case Regex.run(~r/^(\s*)(.*)$/, line) do
      [_, indent, content] -> {indent, content}
      _ -> {"", line}
    end
  end

  @doc """
  Wraps a single line of text at the specified width.
  """
  @spec wrap_line(String.t(), pos_integer()) :: [String.t()]
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

  @doc """
  Formats a cost value in dollars to a human-readable string with cents.
  """
  @spec format_cost(float()) :: String.t()
  defp format_cost(cost) do
    cents = round(cost * 100)

    if cents == 0 do
      "0¢"
    else
      "#{cents}¢"
    end
  end
end

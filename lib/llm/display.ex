defmodule Llm.Display do
  @moduledoc """
  Handles color-coded text formatting and display with support for ANSI colors,
  text wrapping, and structured output formatting.
  """

  @type color_scheme :: %{
          optional(:text) => String.t(),
          optional(:label) => String.t(),
          optional(:error) => String.t(),
          optional(:info) => String.t(),
          optional(:reset) => String.t()
        }

  @default_colors %{
    text: IO.ANSI.normal(),
    label: IO.ANSI.yellow(),
    error: IO.ANSI.red(),
    info: IO.ANSI.cyan(),
    reset: IO.ANSI.reset()
  }

  @doc """
  Creates a new display context with optional custom color scheme.
  """
  @spec new(color_scheme()) :: color_scheme()
  def new(colors \\ %{}) do
    Map.merge(@default_colors, colors)
  end

  @doc """
  Formats and wraps text with proper indentation and width constraints.
  """
  @spec format_text(String.t(), keyword()) :: String.t()
  def format_text(text, opts \\ []) do
    width = Keyword.get(opts, :width, 80)

    text
    |> String.split("\n\n")
    |> Enum.map(&wrap_text(&1, width))
    |> Enum.join("\n\n")
  end

  @doc """
  Displays text with a colored label prefix.
  """
  @spec display_labeled(String.t(), String.t(), color_scheme()) :: :ok
  def display_labeled(label, text, colors) do
    IO.puts("#{colors.label}[#{label}]#{colors.reset} #{text}")
  end

  @doc """
  Displays a message block with a label and formatted content.
  """
  @spec display_block(String.t(), String.t(), color_scheme(), keyword()) :: :ok
  def display_block(label, content, colors, opts \\ []) do
    formatted_content = format_text(content, opts)

    IO.puts("")
    IO.puts("#{colors.label}[#{label}]#{colors.reset}")
    IO.puts("#{colors.text}#{formatted_content}#{colors.reset}")
    IO.puts("")
  end

  @doc """
  Displays an error message with appropriate formatting.
  """
  @spec display_error(String.t(), String.t(), color_scheme()) :: :ok
  def display_error(label, error, colors) do
    IO.puts("#{colors.error}[#{label}] Error: #{inspect(error)}#{colors.reset}\n")
  end

  # Private helper functions
  defp wrap_text(text, width) do
    text
    |> String.split("\n")
    |> Enum.map(fn line ->
      {indent, content} = extract_indent(line)
      wrapped = wrap_line(content, width - String.length(indent))
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
end

defmodule Llm.Client.OptionHelpers do
  def set_default(key, default) do
    fn value, opts ->
      Map.put(opts, key, value || default)
    end
  end

  def rename_key(old_key, new_key) do
    fn value, opts ->
      case value do
        nil -> opts
        _ -> opts |> Map.delete(old_key) |> Map.put(new_key, value)
      end
    end
  end

  def transform_value(key, transform_fn) do
    fn value, opts ->
      case value do
        nil -> opts
        _ -> Map.put(opts, key, transform_fn.(value))
      end
    end
  end

  def compose(processors) when is_list(processors) do
    fn value, opts ->
      Enum.reduce(processors, opts, fn processor, acc ->
        processor.(value, acc)
      end)
    end
  end
end

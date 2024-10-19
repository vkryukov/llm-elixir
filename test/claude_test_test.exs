defmodule ClaudeTestTest do
  use ExUnit.Case
  doctest ClaudeTest

  test "greets the world" do
    assert ClaudeTest.hello() == :world
  end
end

#!/bin/zsh
set -e
cd "${0:A:h}"
# Импортируем новые изображения и ресурсы до компиляции тестов.
tools/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
test_output="$(tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_game.gd 2>&1)"
print -r -- "$test_output"
if print -r -- "$test_output" | grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script'; then
	print -u2 -- "Godot reported a script compilation/runtime error"
	exit 1
fi
if ! print -r -- "$test_output" | grep -Eq 'TESTS: [0-9]+ passed, 0 failed'; then
	print -u2 -- "Test success marker was not found"
	exit 1
fi

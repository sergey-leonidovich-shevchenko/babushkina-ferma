#!/bin/zsh
set -e
cd "${0:A:h}"
if [[ -n "$FARM_GODOT_BIN" ]]; then
	game_godot="$FARM_GODOT_BIN"
elif [[ -x tools/Godot.app/Contents/MacOS/Godot ]]; then
	game_godot="tools/Godot.app/Contents/MacOS/Godot"
elif command -v godot >/dev/null 2>&1; then
	game_godot="$(command -v godot)"
else
	print -u2 -- "Godot executable not found"
	exit 1
fi
# Импортируем новые изображения и ресурсы до компиляции тестов.
"$game_godot" --headless --editor --path . --quit
test_output="$("$game_godot" --headless --path . --script res://tests/test_game.gd 2>&1)"
print -r -- "$test_output"
if print -r -- "$test_output" | grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script'; then
	print -u2 -- "Godot reported a script compilation/runtime error"
	exit 1
fi
if ! print -r -- "$test_output" | grep -Eq 'TESTS: [0-9]+ passed, 0 failed'; then
	print -u2 -- "Test success marker was not found"
	exit 1
fi

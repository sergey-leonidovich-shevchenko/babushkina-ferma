#!/bin/zsh
set -e

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

resolve_godot_path() {
	local candidate
	if [[ -n "$FARM_GODOT_BIN" && -x "$FARM_GODOT_BIN" ]]; then
		echo "$FARM_GODOT_BIN"
		return 0
	fi

	for candidate in \
		"tools/Godot.app/Contents/MacOS/Godot" \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"/Applications/Godot 4.app/Contents/MacOS/Godot" \
		"godot"
	do
		if command -v "$candidate" >/dev/null 2>&1; then
			command -v "$candidate"
			return 0
		fi
		if [[ -x "$candidate" ]]; then
			echo "$candidate"
			return 0
		fi
	done

	return 1
}

game_godot="$(resolve_godot_path)" || {
	print -u2 -- "Godot executable not found. Set FARM_GODOT_BIN to a valid executable path."
	exit 1
}

"$game_godot" --version >/dev/null
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

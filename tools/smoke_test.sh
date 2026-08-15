#!/bin/zsh
set -e

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
game_godot="${FARM_GODOT_BIN:-tools/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$game_godot" ]]; then
	print -u2 -- "SMOKE: Godot не найден: $game_godot"
	exit 1
fi

output="$($game_godot --headless --path . --quit-after 180 -- --autoplay 2>&1)"
if print -r -- "$output" | rg -q 'SCRIPT ERROR|Parse Error|Invalid game content|ERROR:'; then
	print -r -- "$output"
	print -u2 -- "SMOKE: игровой маршрут завершился с ошибкой"
	exit 1
fi
print -- "SMOKE: старт, игровой цикл и автопереход локации прошли 180 кадров"

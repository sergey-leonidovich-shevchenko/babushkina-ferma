#!/bin/zsh
set -e

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
game_godot="${FARM_GODOT_BIN:-tools/Godot.app/Contents/MacOS/Godot}"
minimum_fps="${FARM_MIN_FPS:-50}"

if [[ ! -x "$game_godot" ]]; then
	print -u2 -- "PERFORMANCE: Godot не найден: $game_godot"
	exit 1
fi

measure_gameplay() {
	local label="$1"
	shift
	local output="$($game_godot --headless --path . --max-fps 60 --quit-after 480 --print-fps -- "$@" 2>&1)"
	if print -r -- "$output" | rg -q 'SCRIPT ERROR|Parse Error|Invalid game content|ERROR:'; then
		print -r -- "$output"
		print -u2 -- "PERFORMANCE: $label завершился с ошибкой"
		exit 1
	fi
	local average="$(print -r -- "$output" | awk '/Project FPS:/ { sum += $3; count += 1 } END { if (count) printf "%.0f", sum/count; else print 0 }')"
	if (( average < minimum_fps )); then
		print -u2 -- "PERFORMANCE: $label — средний FPS $average ниже порога $minimum_fps"
		exit 1
	fi
	print -- "PERFORMANCE: $label · средний FPS $average · порог $minimum_fps · 480 кадров"
}

measure_gameplay "обычная игра" --autoplay
measure_gameplay "игра с F10" --autoplay --benchmark-debug-overlay

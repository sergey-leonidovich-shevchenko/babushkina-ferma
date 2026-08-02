#!/bin/zsh
set -e

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

check_limit() {
	local file_path="$1"
	local limit="$2"
	local lines
	lines="$(wc -l < "$file_path" | tr -d ' ')"
	if (( lines > limit )); then
		print -u2 -- "Architecture limit exceeded: $file_path has $lines lines (max $limit)"
		exit 1
	fi
}

check_limit scripts/game.gd 1100
check_limit scripts/game_renderer.gd 700
check_limit scripts/game_context.gd 350
for suite in tests/suites/*_suite.gd; do
	check_limit "$suite" 350
done

if rg -n '^func draw_' scripts/game.gd >/dev/null; then
	print -u2 -- "Rendering leaked back into scripts/game.gd"
	exit 1
fi

git diff --check
print -- "ARCHITECTURE: boundaries and whitespace are valid"

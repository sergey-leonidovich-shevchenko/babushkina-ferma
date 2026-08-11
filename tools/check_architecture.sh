#!/bin/zsh
set -e

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

## Считает только исполняемые строки, чтобы русская документация не расходовала архитектурный лимит.
check_limit() {
	local file_path="$1"
	local limit="$2"
	local lines
	lines="$(awk 'NF && $0 !~ /^[[:space:]]*#/ { count += 1 } END { print count + 0 }' "$file_path")"
	if (( lines > limit )); then
		print -u2 -- "Architecture limit exceeded: $file_path has $lines lines (max $limit)"
		exit 1
	fi
}

check_limit scripts/game.gd 1100
check_limit scripts/game_core.gd 1200
check_limit scripts/game_renderer.gd 700
check_limit scripts/game_context.gd 350
for suite in tests/suites/*_suite.gd; do
	check_limit "$suite" 350
done

if rg -n '^func draw_' scripts/game.gd >/dev/null; then
	print -u2 -- "Rendering leaked back into scripts/game.gd"
	exit 1
fi

python3 tools/check_documentation.py
git diff --check
print -- "ARCHITECTURE: boundaries and whitespace are valid"

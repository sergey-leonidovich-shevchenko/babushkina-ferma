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

# Атомарно резервируем новый корень до запуска движка: прежние доказательства не трогаем.
redraw_capture_root="$FARM_REDRAW_TEST_OUTPUT"
if [[ -n "$redraw_capture_root" ]] && ! mkdir "$redraw_capture_root"; then
	print -u2 -- "Fresh redraw output root with an existing parent is required"
	exit 1
fi

"$game_godot" --version >/dev/null
# Импортируем новые изображения и ресурсы до компиляции тестов.
"$game_godot" --headless --editor --path . --quit

# Храним многотысячный подробный вывод во временном файле, чтобы shell не переполнял буфер команды.
test_log="$(mktemp /tmp/babushkina-ferma-tests.XXXXXX)"
trap 'rm -f "$test_log"' EXIT
set +e
"$game_godot" --headless --path . --script res://tests/test_game.gd >"$test_log" 2>&1
test_code=$?
set -e
if grep -Eq '^ERROR:|SCRIPT ERROR|Parse Error|Failed to load script' "$test_log"; then
	cat "$test_log"
	print -u2 -- "Godot reported an engine, compilation or runtime error"
	exit 1
fi
if [[ $test_code -ne 0 ]] || ! grep -Eq 'TESTS: [0-9]+ passed, 0 failed' "$test_log"; then
	grep -E 'FAIL:|SCRIPT ERROR|Parse Error|Failed to load script' "$test_log" || true
	tail -100 "$test_log"
	print -u2 -- "Test success marker was not found"
	exit 1
fi
grep -E 'TESTS: [0-9]+ passed, 0 failed' "$test_log" | tail -1

# Реальная main-сцена: catch-up физики не должен повторять полную отрисовку между шагами.
for redraw_mode in normal f10; do
	redraw_options=(--autoplay "--redraw-mode=$redraw_mode")
	if [[ "$redraw_mode" == "f10" ]]; then
		redraw_options+=(--benchmark-debug-overlay)
	fi
	set +e
	"$game_godot" --headless --path . --script res://tools/redraw_frame_review.gd -- "${redraw_options[@]}" >"$test_log" 2>&1
	redraw_code=$?
	set -e
	if [[ -n "$redraw_capture_root" ]]; then
		redraw_capture_mode="$redraw_capture_root/$redraw_mode"
		# GDScript мог отказать до создания mode; каталог всё равно принадлежит нашему новому корню.
		if [[ -L "$redraw_capture_mode" ]]; then
			print -u2 -- "Owned redraw mode directory is required"
			exit 1
		fi
		if [[ ! -d "$redraw_capture_mode" ]]; then
			if ! mkdir "$redraw_capture_mode"; then
				print -u2 -- "Owned redraw mode directory is required"
				exit 1
			fi
		fi
		# Даже внутри своего опыта не заменяем уже существующий файл или ссылку на него.
		redraw_capture_log="$redraw_capture_mode/engine.txt"
		if [[ -e "$redraw_capture_log" || -L "$redraw_capture_log" ]]; then
			print -u2 -- "Refusing to overwrite redraw engine evidence"
			exit 1
		fi
		if ! (setopt NO_CLOBBER; cat "$test_log" > "$redraw_capture_log"); then
			print -u2 -- "Refusing to overwrite redraw engine evidence"
			exit 1
		fi
	fi
	if [[ $redraw_code -ne 0 ]] || grep -Eq 'ERROR:|SCRIPT ERROR|Parse Error|Failed to load script' "$test_log" || ! grep -Eq '^REDRAW: [0-9]+ passed, 0 failed$' "$test_log"; then
		cat "$test_log"
		print -u2 -- "Actual-main redraw regression failed: $redraw_mode"
		exit 1
	fi
	grep -E '^REDRAW: [0-9]+ passed, 0 failed$' "$test_log"
done

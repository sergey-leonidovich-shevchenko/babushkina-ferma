extends SceneTree

const Game := preload("res://scripts/game.gd")
const Inspector := preload("res://scripts/systems/debug_object_inspector_system.gd")
const ITERATIONS := 600
const SAMPLES := 9


## Измеряет реальные запросы курсора без кеш-попаданий и сравнивает их с предыдущим модулем инспектора.
func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var baseline_path := argument(arguments, "--baseline=", "")
	var output := argument(arguments, "--report=", "user://inspector_benchmark.json")
	var baseline: Script = Inspector if baseline_path.is_empty() else load(baseline_path)
	if baseline == null:
		push_error("Не найден baseline инспектора"); quit(1); return
	seed(20260908)
	var game := Game.new(); game._ready()
	game.LocaleSystem.set_locale("ru"); game.language_screen = false; game.title_screen = false
	game.current_location = "overworld"; game.camera_offset = Vector2.ZERO
	var probes: Array[Vector2] = [Vector2(220, 220), Vector2(400, 400), Vector2(500, 680), Vector2(1200, 700), Vector2(1500, 350), Vector2(1500, 750)]
	measure(baseline, game, probes, 60); measure(Inspector, game, probes, 60)
	var before: Array[float] = []; var after: Array[float] = []; var equal_results := true
	for sample in SAMPLES:
		var first := measure(baseline if sample % 2 == 0 else Inspector, game, probes, ITERATIONS)
		var second := measure(Inspector if sample % 2 == 0 else baseline, game, probes, ITERATIONS)
		before.append(first.ms if sample % 2 == 0 else second.ms)
		after.append(second.ms if sample % 2 == 0 else first.ms)
		equal_results = equal_results and first.targets == second.targets
	var before_sorted := before.duplicate(); before_sorted.sort()
	var after_sorted := after.duplicate(); after_sorted.sort()
	var report := {"godot":Engine.get_version_info().string, "seed":20260908, "baseline_ref":argument(arguments, "--baseline-ref=", ""), "iterations_per_sample":ITERATIONS, "samples":SAMPLES, "cache_cleared_per_query":true, "baseline_ms":before, "current_ms":after, "baseline_median_ms":before_sorted[SAMPLES / 2], "current_median_ms":after_sorted[SAMPLES / 2], "equal_targets":equal_results, "current_source_sha256":FileAccess.get_file_as_string("res://scripts/systems/debug_object_inspector_system.gd").sha256_text()}
	game.free()
	if not equal_results:
		push_error("Инспектор выбирает другие объекты"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить замер инспектора"); quit(1); return
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("INSPECTOR: %.3f -> %.3f ms, same targets: %s" % [before_sorted[SAMPLES / 2], after_sorted[SAMPLES / 2], str(equal_results)])
	print("INSPECTOR REPORT: ", output); quit(0)


## Читает пользовательский аргумент с заданным префиксом.
func argument(arguments: PackedStringArray, prefix: String, fallback: String) -> String:
	for value in arguments:
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return fallback


## Выполняет одинаковую последовательность запросов курсора, сохраняя выбранные ID и подробности каждого объекта.
func measure(module: Script, game: Node, probes: Array[Vector2], iterations: int) -> Dictionary:
	var targets: Array[Dictionary] = []
	var started := Time.get_ticks_usec()
	for index in iterations:
		if game.has_meta("debug_hover_cache"): game.remove_meta("debug_hover_cache")
		targets.append(module.hovered_object(game, probes[index % probes.size()]))
	return {"ms":float(Time.get_ticks_usec() - started) / 1000.0, "targets":targets}

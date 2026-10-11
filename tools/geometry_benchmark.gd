extends SceneTree

const MODULES := {
	"world":"world_visual_profile_system.gd",
	"loot":"world_loot_visual_system.gd",
	"buildings":"building_visual_system.gd",
}
const ITERATIONS := 20000
const SAMPLES := 9


## Сравнивает CPU-стоимость геометрии с сохранёнными модулями, чередуя порядок замеров после прогрева.
func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var baseline_dir := argument(arguments, "--baseline-dir=", "")
	var output := argument(arguments, "--report=", "user://geometry_benchmark.json")
	var report := {"godot":Engine.get_version_info().string, "iterations_per_sample":ITERATIONS, "samples":SAMPLES, "baseline_ref":argument(arguments, "--baseline-ref=", ""), "families":{}}
	for family in MODULES:
		var current_path: String = "res://scripts/systems/" + MODULES[family]
		var current: Script = load(current_path)
		var baseline: Script = current if baseline_dir.is_empty() else load(baseline_dir.path_join(MODULES[family]))
		if current == null or baseline == null:
			push_error("Не найден модуль геометрии: %s" % family); quit(1); return
		measure(current, family, 500); measure(baseline, family, 500)
		var before: Array[float] = []; var after: Array[float] = []; var equal_results := true
		for sample in SAMPLES:
			var first: Dictionary = measure(baseline if sample % 2 == 0 else current, family, ITERATIONS)
			var second: Dictionary = measure(current if sample % 2 == 0 else baseline, family, ITERATIONS)
			before.append(first.ms if sample % 2 == 0 else second.ms)
			after.append(second.ms if sample % 2 == 0 else first.ms)
			equal_results = equal_results and first.checksum == second.checksum
		var before_sorted := before.duplicate(); before_sorted.sort()
		var after_sorted := after.duplicate(); after_sorted.sort()
		report.families[family] = {"baseline_ms":before, "current_ms":after, "baseline_median_ms":before_sorted[SAMPLES / 2], "current_median_ms":after_sorted[SAMPLES / 2], "equal_results":equal_results, "current_source_sha256":FileAccess.get_file_as_string(current_path).sha256_text()}
		print("GEOMETRY %s: %.3f -> %.3f ms, same results: %s" % [family, before_sorted[SAMPLES / 2], after_sorted[SAMPLES / 2], str(equal_results)])
		if not equal_results:
			push_error("Геометрия отличается от baseline: %s" % family); quit(1); return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить замер геометрии: %s" % output); quit(1); return
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("GEOMETRY REPORT: ", output); quit(0)


## Читает именованный пользовательский аргумент либо возвращает установленное значение по умолчанию.
func argument(arguments: PackedStringArray, prefix: String, fallback: String) -> String:
	for value in arguments:
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return fallback


## Измеряет одинаковую серию запросов реальных профилей без рендера, сохраняя контрольную сумму геометрии.
func measure(module: Script, family: String, iterations: int) -> Dictionary:
	var ids: Array = module.PROFILES.keys()
	var position := Vector2(-120, 240)
	var checksum := 0.0
	var started := Time.get_ticks_usec()
	for index in iterations:
		var id: String = ids[index % ids.size()]
		if family == "buildings":
			var facade: Rect2 = module.destination_rect(id, position); var door: Rect2 = module.door_rect(id, position)
			var bounds: Rect2 = module.collision_bounds(id, position); var walls: Array[Rect2] = module.collision_rects(id, position)
			checksum += facade.position.x + facade.size.y + door.size.x + bounds.size.x + walls[0].size.x + walls[1].position.y
		else:
			var visual: Rect2 = module.visual_rect(id, position); var collision: Rect2 = module.collision_rect(id, position)
			checksum += visual.position.x + visual.position.y + visual.size.x + visual.size.y + collision.position.x + collision.position.y + collision.size.x + collision.size.y
	return {"ms":float(Time.get_ticks_usec() - started) / 1000.0, "checksum":checksum}

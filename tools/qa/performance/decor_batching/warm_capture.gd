extends "res://tools/qa/performance/pass_cost/capture.gd"

const Mode := preload("res://tools/qa/performance/decor_batching/capture_mode.gd")
const CACHE_FIELDS := ["draw_id", "revision", "terrain_ready"]

var variant := ""
var _background: Mode.Background
var _bootstrap := {}
var _cache_rows := PackedInt64Array()


## Переиспользует приёмку маршрута и сбор сырых интервалов из VPERF-003.
func _start() -> void:
	variant = OS.get_environment("VPERF006_VARIANT")
	if variant not in Mode.VARIANTS or route_only or omitted != "baseline":
		push_error("VPERF-006: требуется нативный тёплый маршрут без выключенных проходов")
		quit(2)
		return
	_cache_rows.resize((MAX_DRAWS + 1) * CACHE_FIELDS.size())
	node_added.connect(_watch_game)
	await super._start()


func _watch_game(node: Node) -> void:
	if node != game:
		return
	node_added.disconnect(_watch_game)
	node.ready.connect(_install_variant, CONNECT_ONE_SHOT)


func _install_variant() -> void:
	_background = game.get_node("WorldBackground") as Mode.Background
	Mode.install(_background, variant)
	_bootstrap_variant.call_deferred()


func _bootstrap_variant() -> void:
	_bootstrap = await Mode.bootstrap(_background)


func _conditions() -> Dictionary:
	var result := super._conditions()
	result["valid"] = (
		result.valid and not _bootstrap.is_empty() and Mode.installed(_background, variant)
	)
	result["decor"] = variant
	result["decor_preset"] = Mode.preset(_background)
	result["decor_terrain"] = Mode.terrain(_background)
	return result


## Записывает состояние кеша в тот же callback, включая начальную границу интервалов.
func _record_draw() -> void:
	if sample_start == 0 or finished:
		return
	var previous_count := frame_count
	var opening := previous_draw == 0
	super._record_draw()
	if frame_count != previous_count or (opening and previous_draw != 0):
		var index := frame_count * CACHE_FIELDS.size()
		_cache_rows[index] = Engine.get_frames_drawn()
		_cache_rows[index + 1] = _background.terrain_revision.revision
		_cache_rows[index + 2] = int(_background.terrain_ready)


## Записывает ограниченный буфер после замера и связывает байты с их процессом.
func _write(name: String, content: String) -> void:
	if name == "run.json":
		_write_cache()
		var origin := {
			"pid": OS.get_process_id(),
			"profile": profile,
			"batch_nodes": Mode.batch_count(_background),
			"raw_sha256":
			{
				"frames": FileAccess.get_sha256(output.path_join("frames.csv")),
				"trajectory": FileAccess.get_sha256(output.path_join("trajectory.csv")),
				"terrain-cache": FileAccess.get_sha256(output.path_join("terrain-cache.csv")),
			},
			"bootstrap": _bootstrap,
		}
		super._write("trace-origin.json", JSON.stringify(origin) + "\n")
		var metadata: Dictionary = JSON.parse_string(content)
		metadata.observer_buffer_bytes += _cache_rows.size() * 8
		content = JSON.stringify(metadata) + "\n"
	super._write(name, content)


func _write_cache() -> void:
	var file := FileAccess.open(output.path_join("terrain-cache.csv"), FileAccess.WRITE)
	file.store_line(",".join(CACHE_FIELDS))
	for row in frame_count + 1 if not first_draw.is_empty() else 0:
		var index := row * CACHE_FIELDS.size()
		file.store_line(
			"%d,%d,%d" % [_cache_rows[index], _cache_rows[index + 1], _cache_rows[index + 2]]
		)

extends "res://tools/qa/performance/pass_cost/capture.gd"

const Mode := preload("res://tools/qa/performance/decor_batching/capture_mode.gd")

var variant := ""
var _background: Mode.Background
var _last_revision := -1
var _last_ready := true
var _terrain_events := []


## Переиспользует приёмку маршрута и сбор сырых интервалов из VPERF-003.
func _start() -> void:
	variant = OS.get_environment("VPERF006_VARIANT")
	if variant not in Mode.VARIANTS or route_only or omitted != "baseline":
		push_error("VPERF-006: требуется нативный тёплый маршрут без выключенных проходов")
		quit(2)
		return
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


func _conditions() -> Dictionary:
	var result := super._conditions()
	result["valid"] = result.valid and Mode.installed(_background, variant)
	result["decor"] = variant
	result["decor_preset"] = Mode.preset(_background)
	result["decor_terrain"] = Mode.terrain(_background)
	if sample_start == 0:
		_last_revision = _background.terrain_revision.revision
	return result


## Помечает смену ревизии и кадры с незавершённым кешем на живом маршруте.
func _record_draw() -> void:
	if sample_start != 0 and not finished:
		var revision: int = _background.terrain_revision.revision
		var ready: bool = _background.terrain_ready
		if not ready or ready != _last_ready or revision != _last_revision:
			(
				_terrain_events
				. append(
					{
						"draw_id": Engine.get_frames_drawn(),
						"revision": revision,
						"terrain_ready": ready,
					}
				)
			)
			_last_revision = revision
			_last_ready = ready
	super._record_draw()


## Связывает сырые CSV с их процессом и фактической группировкой до упаковки архива.
func _write(name: String, content: String) -> void:
	if name == "run.json":
		var origin := {
			"pid": OS.get_process_id(),
			"profile": profile,
			"batch_nodes": Mode.batch_count(_background),
			"raw_sha256":
			{
				"frames": FileAccess.get_sha256(output.path_join("frames.csv")),
				"trajectory": FileAccess.get_sha256(output.path_join("trajectory.csv")),
			},
			"events": _terrain_events,
		}
		super._write("terrain-events.json", JSON.stringify(origin) + "\n")
	super._write(name, content)

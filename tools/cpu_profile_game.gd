extends "res://scripts/game.gd"

## Сохраняет отдельный CPU-замер, не внедряя диагностический конвейер в production-системы.
func record_cpu(section: String, started_usec: int) -> void:
	var values: Dictionary=get_meta("cpu_samples",{})
	if not values.has(section): values[section]=[]
	values[section].append((Time.get_ticks_usec()-started_usec)/1000.0)
	set_meta("cpu_samples",values)

## Измеряет полный физический тик без изменения обычного порядка подсистем.
func _physics_process(delta: float) -> void:
	var started:=Time.get_ticks_usec(); super._physics_process(delta); record_cpu("physics_tick",started)

## Измеряет обычных врагов, босса и растения одним реально вызываемым боевым маршрутом.
func update_combat(delta: float) -> void:
	var started:=Time.get_ticks_usec(); super.update_combat(delta); record_cpu("combat",started)

## Измеряет движение и навигацию героя отдельно от AI противников.
func update_player_movement(delta: float) -> void:
	var started:=Time.get_ticks_usec(); super.update_player_movement(delta); record_cpu("player_navigation",started)

## Измеряет обновление культуры через реальную обёртку игрового ядра.
func update_crops(delta: float) -> void:
	var started:=Time.get_ticks_usec(); super.update_crops(delta); record_cpu("crops",started)

## Измеряет продолжение рыбалки в обычном игровом цикле.
func update_fishing(delta: float) -> void:
	var started:=Time.get_ticks_usec(); super.update_fishing(delta); record_cpu("fishing",started)

## Измеряет интерфейс и мировую отрисовку без подмены реального renderer.
func _draw() -> void:
	var started:=Time.get_ticks_usec(); super._draw(); record_cpu("draw",started)

## Измеряет мировой проход отдельно от экранного интерфейса.
func draw_world() -> void:
	var started:=Time.get_ticks_usec(); super.draw_world(); record_cpu("draw_world",started)

## Измеряет мировой слой игровых объектов.
func draw_rpg_world() -> void:
	var started:=Time.get_ticks_usec(); super.draw_rpg_world(); record_cpu("draw_rpg_world",started)

## Измеряет экранный интерфейс, включая открытую панель F10.
func draw_ui() -> void:
	var started:=Time.get_ticks_usec(); super.draw_ui(); record_cpu("draw_ui",started)
